import eyg/analysis/inference/levels_j/contextual as j
import eyg/analysis/type_/binding
import eyg/analysis/type_/isomorphic as type_
import eyg/parse
import eyg/runtime/break
import eyg/runtime/cast
import eyg/runtime/interpreter/runner as r
import eyg/runtime/interpreter/state.{type Env, type Stack} as istate
import eyg/runtime/value as v
import eygir/annotated.{type Expression}
import eygir/decode
import gleam/bit_array
import gleam/dict.{type Dict}
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
import lustre/effect
import lustre/element.{type Element}
import midas/task as t
import plinth/browser/geolocation
import plinth/javascript/global
import snag

// circular dependency on content potential if init calls content and content needs sections
// init should take some value
pub type Section =
  #(Element(Message), String)

pub type Effect {
  Awaited(Value)
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
  // TODO change request to bitarray
  Fetch(request: Request(String))
}

pub type Handle {
  Abort(String)
  Suspended(for: For, Env(Nil), Stack(Nil))
  Done(Value)
}

pub type Runner {
  Runner(handle: Handle, effects: List(Effect))
}

pub type State {
  State(
    references: Dict(String, #(Value, binding.Poly)),
    sections: List(Section),
    running: Option(Runner),
  )
}

pub fn init(_) {
  let sections = content.sections()
  let refs = dict.new()

  let state = State(refs, sections, None)
  #(state, effect.from(load_new_references(sections, refs, _)))
}

fn load_new_references(sections, refs, d) {
  let new_refs =
    list.flat_map(sections, fn(section) {
      let #(_context, code) = section
      find_new_references(code, refs)
    })
    |> list.unique()

  list.map(new_refs, fn(reference) {
    let task = do_load(reference)
    promise.map(browser_run(task), fn(result) {
      case result {
        Ok(value) -> {
          d(LoadedReference(reference, value, True))
        }
        Error(reason) -> io.println(snag.pretty_print(reason))
      }
    })
  })
  Nil
}

pub type Message {
  EditCode(sections: List(#(Element(Message), String)))
  UpdateSuspend(For)
  Run(#(Expression(#(Int, Int)), #(Int, Int)))
  Unsuspend(Effect)
  // execute after assumes boolean information probably should be list of args and/or reference to possible effects
  LoadedReference(
    reference: String,
    value: #(Value, binding.Poly),
    // TODO remove when suspense state has all the inforation
    execute_after: Bool,
  )
  CloseRunner
}

type Value =
  v.Value(Nil, #(List(#(istate.Kontinue(Nil), Nil)), istate.Env(Nil)))

// only two cases. eval is inline before calling no further handlers but will call
fn eval(source: #(Expression(#(Int, Int)), #(Int, Int)), references) {
  let source = annotated.map_annotation(source, fn(_) { Nil })
  let handlers = dict.new()
  let env = istate.Env(..stdlib.env(), references: references)
  handle_eval(r.execute(source, env, handlers), references)
}

fn handle_eval(result, references) {
  let env = istate.Env(..stdlib.env(), references: references)
  case result {
    Ok(f) -> {
      handle_next(r.resume(f, [v.unit], env, dict.new()), [], references)
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

pub fn all_errors(exp, references) {
  let #(exp, _bindings) =
    j.infer(exp, type_.Empty, references, 0, j.new_state())
  let acc = annotated.strip_annotation(exp).1
  list.filter_map(acc, fn(node) {
    let #(type_error, _typed, _effect, _env) = node
    case type_error {
      Ok(Nil) -> Error(Nil)
      Error(reason) -> Ok(reason)
    }
  })
}

pub fn information(source, references) {
  let #(tree, spans) = annotated.strip_annotation(source)
  let #(exp, _bindings) =
    j.infer(tree, type_.Empty, references, 0, j.new_state())
  let acc = annotated.strip_annotation(exp).1
  let acc =
    list.map(acc, fn(node) {
      let #(error, _typed, _effect, _env) = node
      error
    })
  let assert Ok(zipped) = list.strict_zip(spans, acc)
  zipped
}

pub fn type_errors(assigns, final, references) {
  let source = case final, assigns {
    None, [#(label, _, span), ..] -> #(annotated.Variable(label), span)
    None, [] -> #(annotated.Empty, #(0, 0))
    Some(other), _ -> other
  }
  let source = rollup_block(source, assigns)
  let errors =
    information(source, references)
    |> list.filter_map(fn(p) {
      let #(span, error) = p
      case error {
        Ok(_) -> Error(Nil)
        Error(reason) -> Ok(#(span, reason))
      }
    })
  // TODO move to text these highlight functions

  let errors =
    list.sort(errors, fn(a, b) {
      let #(#(start_a, _end), _reason) = a
      let #(#(start_b, _end), _reason) = b
      int.compare(start_a, start_b)
    })
  let #(_max, errors) =
    list.map_fold(errors, 0, fn(max, value) {
      let #(#(start, end), reason) = value
      let #(max, span) = case start {
        _ if max <= start -> #(end, #(start, end))
        _ if max <= end -> #(end, #(max, end))
        _ -> #(max, #(max, max))
      }
      #(max, #(span, reason))
    })
  errors
}

// expects reversed
pub fn rollup_block(exp, assigns) {
  case assigns {
    [] -> exp
    [#(label, value, span), ..assigns] ->
      rollup_block(#(annotated.Let(label, value, exp), span), assigns)
  }
}

fn used_references(code) {
  case parse.block_from_string(code) {
    Ok(#(#(assigns, exp), _rest)) -> {
      let tail = option.unwrap(exp, #(annotated.Empty, #(0, 0)))
      let exp = rollup_block(tail, assigns)
      annotated.list_builtins(exp)
    }
    Error(_) -> []
  }
  |> list.filter_map(fn(identifier) {
    case identifier {
      "#" <> ref -> Ok(ref)
      _ -> Error(Nil)
    }
  })
}

fn find_new_references(code, existing) {
  let used = used_references(code)
  list.filter(used, fn(ref) { !dict.has_key(existing, ref) })
}

pub fn update(state, message) {
  let State(references: references, ..) = state
  case message {
    EditCode(sections) -> {
      let state = State(..state, sections: sections)
      #(state, effect.from(load_new_references(sections, references, _)))
    }
    UpdateSuspend(for) -> {
      let State(running: running, ..) = state
      let assert Some(Runner(Suspended(_, env, k), effects)) = running

      let state =
        State(..state, running: Some(Runner(Suspended(for, env, k), effects)))
      #(state, effect.none())
    }
    Run(source) -> {
      let references = dict.map_values(references, fn(_, v) { pair.first(v) })
      let #(run, effect) = eval(source, references)
      let state = State(..state, running: Some(run))
      #(state, effect)
    }

    Unsuspend(effect) -> {
      let State(running: running, ..) = state
      let assert Some(Runner(Suspended(_, env, k), effects)) = running

      let value = reply_value(effect)
      let result = r.loop(istate.step(istate.V(value), env, k))
      let effects = [effect, ..effects]
      let #(run, effect) = handle_next(result, effects, references)

      let state = State(..state, running: Some(run))
      #(state, effect)
    }

    LoadedReference(reference, value, execute_after) -> {
      let State(references: references, running: running, ..) = state
      io.println("Added reference: " <> reference)
      let references = dict.insert(references, reference, value)

      let #(run, effect) = case running {
        Some(Runner(Suspended(Loading(r), env, k), effects)) if r == reference -> {
          let #(value, _) = value
          let result = r.loop(istate.step(istate.V(value), env, k))
          let references =
            dict.map_values(references, fn(_, v) { pair.first(v) })
          let #(run, effect) = case execute_after {
            True -> handle_eval(result, references)
            False -> handle_next(result, effects, references)
          }
          #(Some(run), effect)
        }
        other -> #(other, effect.none())
      }
      let state = State(..state, references: references, running: run)
      #(state, effect)
    }
    CloseRunner -> {
      let state = State(..state, running: None)
      #(state, effect.none())
    }
  }
}

fn reply_value(effect) {
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
  use file <- t.try(case reference {
    "standard_library" -> Ok("std.json")
    "json" -> Ok("json.json")

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

  // use body <- t.try(case bit_array.to_string(body) {
  //   Ok(data) -> Ok(data)
  //   Error(Nil) -> Error(snag.new("Not utf8 formatted."))
  // })

  use source <- t.try(
    decode.from_json(body)
    |> result.replace_error(snag.new("Unable to decode source code.")),
  )
  io.println("Decoded source for reference: " <> reference)

  all_errors(source, dict.new())
  |> io.debug
  let #(exp, bindings) =
    j.infer(source, type_.Empty, dict.new(), 0, j.new_state())

  let #(_, type_info) = exp
  let #(_res, typevar, _eff, _hmm) = type_info

  let poly = binding.gen(typevar, 0, bindings)

  let env = stdlib.env()
  let handlers = dict.new()
  let source = annotated.add_annotation(source, Nil)

  use value <- t.try(
    r.execute(source, env, handlers)
    |> result.replace_error(snag.new("Unable to evaluate reference.")),
  )

  t.done(#(value, poly))
}

fn handle_next(result, effects, references) {
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
              let assert Ok(request) = http.request_to_gleam(lift)
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
