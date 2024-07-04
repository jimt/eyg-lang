import eyg/parse/parser.{type Span}
import eyg/runtime/break
import eyg/runtime/cast
import eyg/runtime/interpreter/runner as r
import eyg/runtime/interpreter/state.{type Env, type Stack} as istate
import eyg/runtime/value as v
import eygir/annotated.{type Expression, type Node}
import eygir/decode
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/fetch as gleam_fetch
import gleam/float
import gleam/http/request.{type Request}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/string
import gleam/uri
import harness/fetch
import harness/http
import harness/stdlib
import intro/content
import intro/snippet.{Processed}
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html as h
import midas/task as t
import plinth/browser/geolocation
import plinth/browser/window
import plinth/javascript/global
import snag

// circular dependency on content potential if init calls content and content needs sections
// init should take some value
pub type Section =
  #(Element(Message), String)

pub type Effect {
  Awaited(snippet.Value)
  Log(String)
  Asked(question: String, answer: String)
  Fetched(request: Request(BitArray))
  Waited(Int)
  Geolocation(reply: Result(geolocation.GeolocationPosition, String))
}

pub type For {
  Loading(reference: String)
  Awaiting
  Geo
  Timer(duration: Int)
  TextInput(question: String, response: String)
}

pub type Handle(a) {
  Abort(String)
  Suspended(for: For, Env(a), Stack(a))
  Done(snippet.Value)
}

pub type Runner(a) {
  Runner(handle: Handle(a), effects: List(Effect))
}

pub type State {
  State(
    loading: List(String),
    references: snippet.Referenced,
    document: snippet.Document(Element(Message)),
    running: Option(#(String, Runner(Span))),
  )
}

pub fn init(_) {
  let references = snippet.empty()
  // Local storage for between pages
  // could renmae type snippet state to Acc
  let sections = case uri.parse(window.location()) {
    Ok(uri.Uri(path: "/guide/" <> slug, ..)) ->
      case list.key_find(content.pages(), slug) {
        Ok(sections) -> sections
        Error(Nil) -> []
      }
    _ -> {
      []
    }
  }
  let #(doc, references) = snippet.process_document(sections, references)
  let missing = snippet.missing_references(doc)

  let state = State(missing, references, doc, None)
  #(state, effect.from(load_new_references(missing, _)))
}

fn load_new_references(missing, d) {
  list.map(missing, fn(reference) {
    let task = do_load(reference)
    promise.map(browser_run(task), fn(result) {
      case result {
        Ok(expression) -> {
          let expression = annotated.add_annotation(expression, #(0, 0))
          d(LoadedReference(reference, expression, True))
        }
        Error(reason) -> io.println(snag.pretty_print(reason))
      }
    })
  })
  Nil
}

pub type Message {
  EditCode(index: Int, content: String)
  UpdateSuspend(For)
  Run(String)
  Unsuspend(Effect)
  // execute after assumes boolean information probably should be list of args and/or reference to possible effects
  LoadedReference(
    reference: String,
    value: Node(Span),
    // TODO remove when suspense state has all the inforation
    execute_after: Bool,
  )
  CloseRunner
}

fn empty_env(references) -> istate.Env(parser.Span) {
  istate.Env(
    ..stdlib.env()
    |> dynamic.from()
    |> dynamic.unsafe_coerce(),
    references: references,
  )
}

// only two cases. eval is inline before calling no further handlers but will call
fn eval(source: Node(Span), references) {
  // let source = annotated.map_annotation(source, fn(_) { Nil })
  let handlers = dict.new()
  let env = empty_env(references)
  handle_eval(r.execute(source, env, handlers), references)
}

fn handle_eval(result: Result(snippet.Value, _), references) {
  let env = empty_env(references)
  case result {
    Ok(f) -> {
      handle_next(
        r.resume(f, [#(v.unit, #(0, 0))], env, dict.new()),
        [],
        references,
      )
    }
    Error(#(reason, meta, env, k)) -> {
      case reason {
        break.UndefinedVariable("#" <> reference) -> #(
          Runner(Suspended(Loading(reference), env, k), []),
          effect.none(),
        )

        _ -> #(
          Runner(
            Abort(break.reason_to_string(reason) <> string.inspect(meta)),
            [],
          ),
          effect.none(),
        )
      }
    }
  }
}

pub fn update(state, message) {
  let State(references: references, ..) = state
  case message {
    EditCode(index, new) -> {
      let State(document: document, ..) = state
      let #(document, references) =
        snippet.update_at(document, index, new, references)
      let missing = snippet.missing_references(document)
      let state = State(..state, document: document, references: references)
      #(state, effect.from(load_new_references(missing, _)))
    }
    UpdateSuspend(for) -> {
      let State(running: running, ..) = state
      let assert Some(#(ref, run)) = running
      let assert Runner(Suspended(_, env, k), effects) = run

      let state =
        State(
          ..state,
          running: Some(#(ref, Runner(Suspended(for, env, k), effects))),
        )
      #(state, effect.none())
    }
    Run(reference) -> {
      let assert Ok(func) = dict.get(references.values, reference)
      let #(run, effect) =
        handle_next(
          r.resume(
            func,
            [#(v.unit, #(0, 0))],
            empty_env(references.values),
            dict.new(),
          ),
          [],
          references,
        )
      let state = State(..state, running: Some(#(reference, run)))
      #(state, effect)
    }

    Unsuspend(effect) -> {
      let State(running: running, ..) = state
      let assert Some(#(ref, run)) = running
      let assert Runner(Suspended(_, env, k), effects) = run

      let value = reply_value(effect)
      let result = r.loop(istate.step(istate.V(value), env, k))
      let effects = [effect, ..effects]
      let #(run, effect) = handle_next(result, effects, references)

      let state = State(..state, running: Some(#(ref, run)))
      #(state, effect)
    }

    LoadedReference(reference, expression, execute_after) -> {
      let State(loading: loading, ..) = state
      let loading = list.filter(loading, fn(l) { l != reference })
      let assert #(errors, result) =
        snippet.install_code(references, [], expression)
      // TODO do we care about errors 
      let references = case result {
        Ok(#(r, references)) -> references
        Error(reason) -> {
          // io.debug(reason)
          io.debug(errors)
          references
        }
      }
      let #(document, references) =
        snippet.reprocess_document(state.document, references)
      // let State(references: references, running: running, ..) = state
      // io.println("Added reference: " <> reference)
      // let references = dict.insert(references, reference, value)

      // let #(run, effect) = case running {
      //   Some(Runner(Suspended(Loading(r), env, k), effects)) if r == reference -> {
      //     let #(value, _) = value
      //     let result = r.loop(istate.step(istate.V(value), env, k))
      //     let references =
      //       dict.map_values(references, fn(_, v) { pair.first(v) })
      //     let #(run, effect) = case execute_after {
      //       True -> handle_eval(result, references)
      //       False -> handle_next(result, effects, references)
      //     }
      //     #(Some(run), effect)
      //   }
      //   other -> #(other, effect.none())
      // }
      let state =
        State(
          ..state,
          references: references,
          loading: loading,
          document: document,
        )
      #(state, effect.none())
    }
    CloseRunner -> {
      let state = State(..state, running: None)
      #(state, effect.none())
    }
  }
}

fn reply_value(effect) -> snippet.Value {
  case effect {
    Geolocation(Ok(geolocation.GeolocationPosition(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      accuracy: accuracy,
      altitude_accuracy: altitude_accuracy,
      heading: heading,
      speed: speed,
      timestamp: timestamp,
    ))) -> {
      v.ok(
        v.Record([
          #("latitude", v.Integer(float.truncate(latitude))),
          #("longitude", v.Integer(float.truncate(longitude))),
          #(
            "altitude",
            v.option(altitude, fn(x) { v.Integer(float.truncate(x)) }),
          ),
          #("accuracy", v.Integer(float.truncate(accuracy))),
          #(
            "altitude_accuracy",
            v.option(altitude_accuracy, fn(x) { v.Integer(float.truncate(x)) }),
          ),
          #(
            "heading",
            v.option(heading, fn(x) { v.Integer(float.truncate(x)) }),
          ),
          #("speed", v.option(speed, fn(x) { v.Integer(float.truncate(x)) })),
          #("timestamp", v.Integer(float.truncate(timestamp))),
        ]),
      )
    }
    Geolocation(Error(reason)) -> v.error(v.Str(reason))
    Asked(_question, answer) -> v.Str(answer)
    Waited(_duration) -> v.unit
    Awaited(value) -> value
    Log(_) -> panic as "log can be dealt with synchronously"
    Fetched(_) -> panic as "fetch returns a promise"
  }
}

fn do_load(reference) {
  io.println("Loading reference: " <> reference)
  use file <- t.try(case reference {
    "standard_library" -> Ok("std.json")
    "h" <> _hash -> Ok(reference <> ".json")
    _ -> Error(snag.new("no file for reference: " <> reference))
  })
  let assert Ok(uri) = uri.parse("http://localhost:8080/saved/" <> file)
  let assert Ok(request) = request.from_uri(uri)
  let request =
    request
    |> request.set_body(<<>>)
  use response <- t.do(t.fetch(request))

  use body <- t.try(case response.status {
    200 -> Ok(response.body)
    other -> Error(snag.new("Bad response status: " <> int.to_string(other)))
  })
  use body <- t.try(
    bit_array.to_string(body)
    |> result.replace_error(snag.new("Not utf8 formatted.")),
  )

  use source <- t.try(
    decode.from_json(body)
    |> result.replace_error(snag.new("Unable to decode source code.")),
  )
  io.println("Decoded source for reference: " <> reference)
  t.done(source)
}

fn handle_next(
  result: Result(snippet.Value, #(_, _, Env(Span), _)),
  effects,
  references,
) {
  case result {
    Error(#(reason, meta, env, k)) ->
      case reason {
        break.UnhandledEffect(label, lift) ->
          case label {
            "Ask" -> {
              let assert Ok(question) = cast.as_string(lift)
              #(
                Runner(Suspended(TextInput(question, ""), env, k), effects),
                effect.none(),
              )
            }
            "Log" -> {
              let assert Ok(message) = cast.as_string(lift)
              let effects = [Log(message), ..effects]
              r.loop(istate.step(istate.V(v.unit), env, k))
              |> handle_next(effects, references)
            }
            "Wait" -> {
              let assert Ok(duration) = cast.as_integer(lift)
              #(
                Runner(Suspended(Timer(duration), env, k), effects),
                effect.from(fn(d) {
                  global.set_timeout(duration, fn() {
                    d(Unsuspend(Waited(duration)))
                    Nil
                  })
                  Nil
                }),
              )
            }
            "Geo" -> {
              #(
                Runner(Suspended(Geo, env, k), effects),
                effect.from(fn(d) {
                  geolocation.current_position()
                  |> promise.map(fn(result) {
                    d(Unsuspend(Geolocation(result)))
                  })
                  Nil
                }),
              )
            }
            "Fetch" -> {
              let assert Ok(request) =
                http.request_to_gleam(lift)
                |> io.debug()
              let task = fetch.do(request)
              let value = fetch.task_to_eyg(task)
              let effects = [Fetched(request), ..effects]

              r.loop(istate.step(istate.V(value), env, k))
              |> handle_next(effects, references)
            }
            "Await" -> {
              let assert Ok(task) = cast.as_promise(lift)
              #(
                Runner(Suspended(Awaiting, env, k), effects),
                effect.from(fn(d) {
                  promise.map(task, fn(value) { d(Unsuspend(Awaited(value))) })
                  Nil
                }),
              )
            }

            _other -> #(
              Runner(
                Abort(break.reason_to_string(reason) <> string.inspect(meta)),
                effects,
              ),
              effect.none(),
            )
          }
        reason -> #(
          Runner(
            Abort(break.reason_to_string(reason) <> string.inspect(meta)),
            effects,
          ),
          effect.none(),
        )
      }
    Ok(value) -> #(Runner(Done(value), effects), effect.none())
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
    _ -> panic as "unsupported effect in browser_run"
  }
}

pub fn do_fetch(request) {
  use response <- promise.await(gleam_fetch.send_bits(request))
  let assert Ok(response) = response
  use response <- promise.await(gleam_fetch.read_bytes_body(response))
  let response = case response {
    Ok(response) -> Ok(response)
    Error(gleam_fetch.NetworkError(s)) -> Error(t.NetworkError(s))
    Error(gleam_fetch.UnableToReadBody) -> Error(t.UnableToReadBody)
    Error(gleam_fetch.InvalidJsonBody) -> panic
  }
  promise.resolve(response)
}
