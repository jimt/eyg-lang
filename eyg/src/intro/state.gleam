import eyg/parse
import eyg/runtime/break
import eyg/runtime/cast
import eyg/runtime/interpreter/runner as r
import eyg/runtime/interpreter/state.{type Env, type Stack} as istate
import eyg/runtime/value as v
import eygir/annotated.{type Expression}
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/fetch
import gleam/http/request
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/uri
import harness/stdlib
import intro/content
import lustre/effect
import lustre/element.{type Element}

// import midas/browser
import midas/task as t
import plinth/javascript/global

// circular dependency on content potential if init calls content and content needs sections
// init should take some value
pub type Section =
  #(Element(Message), String)

pub type Effect {
  Log(String)
  Asked(question: String, answer: String)
  Waited(Int)
  Random(Int)
}

pub type Handle {
  Abort(String)
  Loading(reference: String, Env(Nil), Stack(Nil))
  Waiting(remaining: Int, Env(Nil), Stack(Nil))
  Asking(question: String, value: String, Env(Nil), Stack(Nil))
  Done(v.Value(Nil, Nil))
}

pub type Runner {
  Runner(handle: Handle, effects: List(Effect))
}

pub type State {
  State(
    references: Dict(String, v.Value(Nil, Nil)),
    sections: List(Section),
    running: Option(Runner),
  )
}

pub fn init(_) {
  let state = State(dict.new(), content.sections(), None)
  #(state, effect.none())
}

pub type Message {
  EditCode(sections: List(#(Element(Message), String)))
  NewRunner(Runner)
  Run(#(Expression(#(Int, Int)), #(Int, Int)))
  Resume(v.Value(Nil, Nil), Env(Nil), Stack(Nil), List(Effect))
  TimerComplete
  CloseRunner
}

pub fn update(state, message) {
  let State(references: references, ..) = state
  case message {
    EditCode(sections) -> {
      let state = State(..state, sections: sections)
      #(state, effect.none())
    }
    NewRunner(running) -> {
      let state = State(..state, running: Some(running))
      #(state, effect.none())
    }
    Run(source) -> {
      let handlers = dict.new()
      let env = dynamic.unsafe_coerce(dynamic.from(stdlib.env()))
      let #(run, effect) = case r.execute(source, env, handlers) {
        Ok(f) -> {
          let f = dynamic.unsafe_coerce(dynamic.from(f))
          handle_next(
            r.resume(f, [v.unit], stdlib.env(), dict.new()),
            [],
            references,
          )
        }
        Error(#(reason, meta, env, k)) -> {
          case reason {
            // TODO need to reuse the code here with handle_next BUT different effects
            break.UndefinedVariable("#" <> reference) -> {
              let env = dynamic.unsafe_coerce(dynamic.from(env))
              let k = dynamic.unsafe_coerce(dynamic.from(k))
              case dict.get(references, reference) {
                Ok(value) -> todo as "return"
                Error(Nil) -> #(
                  Runner(Loading(reference, env, k), []),
                  effect.from(fn(d) {
                    let task = do_load(reference)
                    browser_run(task)
                    Nil
                  }),
                )
              }
            }
            _ -> #(
              Runner(Abort(break.reason_to_string(reason)), []),
              effect.none(),
            )
          }
        }
      }
      let state = State(..state, running: Some(run))
      #(state, effect)
    }
    Resume(value, env, k, effects) -> {
      // r.resume(k, [value], env, dict.new())
      let value = dynamic.unsafe_coerce(dynamic.from(value))
      let result = r.loop(istate.step(istate.V(value), env, k))
      let #(run, effect) = handle_next(result, effects, references)
      let state = State(..state, running: Some(run))
      #(state, effect)
    }
    TimerComplete -> {
      let State(sections: sections, running: running, ..) = state
      let assert Some(Runner(Waiting(remaining, env, k), effects)) = running
      let value = dynamic.unsafe_coerce(dynamic.from(v.unit))
      let result = r.loop(istate.step(istate.V(value), env, k))
      let effects = [Waited(remaining), ..effects]
      let #(run, effect) = handle_next(result, effects, references)

      let state = State(..state, running: Some(run))
      #(state, effect)
    }
    CloseRunner -> {
      let state = State(..state, running: None)
      #(state, effect.none())
    }
  }
}

fn do_load(reference) {
  // magpie fetch
  io.debug("loading")
  let assert Ok(uri) = uri.parse("http://localhost:8080/saved/std.json")
  let assert Ok(request) = request.from_uri(uri)
  let request =
    request
    |> request.set_body(<<>>)
  io.debug(request)
  use response <- t.do(t.fetch(request))
  response
  |> io.debug
  t.done(Nil)
}

fn handle_next(result, effects, references) {
  case result {
    Error(#(reason, meta, env, k)) ->
      case reason {
        break.UnhandledEffect(label, lift) ->
          case label {
            "Ask" -> {
              let assert Ok(question) = cast.as_string(lift)
              #(Runner(Asking(question, "", env, k), effects), effect.none())
            }
            "Log" -> {
              let assert Ok(message) = cast.as_string(lift)
              let effects = [Log(message), ..effects]
              r.loop(istate.step(istate.V(v.unit), env, k))
              |> handle_next(effects, references)
            }
            "Wait" -> {
              let assert Ok(remaining) = cast.as_integer(lift)
              #(
                Runner(Waiting(remaining, env, k), effects),
                effect.from(fn(d) {
                  global.set_timeout(remaining, fn() {
                    d(TimerComplete)
                    Nil
                  })
                  Nil
                }),
              )
            }

            other -> #(
              Runner(Abort(break.reason_to_string(reason)), effects),
              effect.none(),
            )
          }
        break.UndefinedVariable("#" <> reference) -> {
          case dict.get(references, reference) {
            Ok(value) -> todo as "return"
            Error(Nil) -> todo as "load"
          }
        }
        reason -> #(
          Runner(Abort(break.reason_to_string(reason)), effects),
          effect.none(),
        )
      }
    Ok(value) -> #(
      Runner(Done(dynamic.unsafe_coerce(dynamic.from(value))), effects),
      effect.none(),
    )
  }
}

import gleam/javascript/promise

// can't be part of main midas reliance on node stuff. would need to be sub package
pub fn browser_run(task) {
  case task {
    t.Done(value) -> promise.resolve(Ok(value))
    t.Abort(reason) -> promise.resolve(Error(reason))

    t.Fetch(request, resume) -> {
      use return <- promise.await(do_fetch(request))
      browser_run(resume(return))
    }
    t.Log(message, resume) -> {
      io.println(message)
      browser_run(resume(Ok(Nil)))
    }
    _ -> todo as "unsupported"
  }
}

pub fn do_fetch(request) {
  use response <- promise.await(fetch.send_bits(request))
  let assert Ok(response) = response
  use response <- promise.await(fetch.read_bytes_body(response))
  let response = case response {
    Ok(response) -> Ok(response)
    Error(fetch.NetworkError(s)) -> Error(t.NetworkError(s))
    Error(fetch.UnableToReadBody) -> Error(t.UnableToReadBody)
    Error(fetch.InvalidJsonBody) -> panic
  }
  promise.resolve(response)
}
