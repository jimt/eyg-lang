import eyg/parse
import eyg/runtime/break
import eyg/runtime/cast
import eyg/runtime/interpreter/runner as r
import eyg/runtime/interpreter/state.{type Env, type Stack} as istate
import eyg/runtime/value as v
import eygir/annotated.{type Expression}
import gleam/dict
import gleam/dynamic
import gleam/io
import gleam/option.{type Option, None, Some}
import harness/stdlib
import intro/content
import lustre/effect
import lustre/element.{type Element}
import plinth/javascript/global

// circular dependency on content potential if init calls content and content needs sections
// init should take some value
pub type Section =
  #(Element(Message), String)

pub type State {
  State(sections: List(Section), running: Option(Runner))
}

pub fn init(_) {
  let state = State(content.sections(), None)
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
          handle_next(r.resume(f, [v.unit], stdlib.env(), dict.new()), [])
        }
        Error(#(reason, meta, env, k)) -> {
          #(Runner(Abort(break.reason_to_string(reason)), []), effect.none())
        }
      }
      let state = State(..state, running: Some(run))
      #(state, effect)
    }
    Resume(value, env, k, effects) -> {
      // r.resume(k, [value], env, dict.new())
      let value = dynamic.unsafe_coerce(dynamic.from(value))
      let result = r.loop(istate.step(istate.V(value), env, k))
      let #(run, effect) = handle_next(result, effects)
      let state = State(..state, running: Some(run))
      #(state, effect)
    }
    TimerComplete -> {
      let State(sections, running) = state
      let assert Some(Runner(Waiting(remaining, env, k), effects)) = running
      let value = dynamic.unsafe_coerce(dynamic.from(v.unit))
      let result = r.loop(istate.step(istate.V(value), env, k))
      let effects = [Waited(remaining), ..effects]
      let #(run, effect) = handle_next(result, effects)

      let state = State(..state, running: Some(run))
      #(state, effect)
    }
    CloseRunner -> {
      let state = State(..state, running: None)
      #(state, effect.none())
    }
  }
}

fn handle_next(result, effects) {
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
              |> handle_next(effects)
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

pub type Effect {
  Log(String)
  Asked(question: String, answer: String)
  Waited(Int)
  Random(Int)
}

pub type Handle {
  Abort(String)
  Waiting(remaining: Int, Env(Nil), Stack(Nil))
  Asking(question: String, value: String, Env(Nil), Stack(Nil))
  Done(v.Value(Nil, Nil))
}

pub type Runner {
  Runner(handle: Handle, effects: List(Effect))
}
