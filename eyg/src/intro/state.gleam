import eyg/parse
import eyg/runtime/interpreter/runner as r
import eyg/runtime/value as v
import gleam/dict
import gleam/dynamic
import gleam/io
import gleam/option.{type Option, None, Some}
import harness/stdlib

import lustre/effect

pub type State {
  State(running: Option(Runner))
}

const effects = [Log("Hello, World!"), Random(5), Log("Hello, World!")]

pub fn init(_) {
  let state = State(Some(Runner(Abort("something went wrong"), effects)))
  #(state, effect.none())
}

pub type Message {
  Run(String)
  CloseRunner
}

pub fn update(state, message) {
  case message {
    Run(code) -> {
      let code = code <> "\r\nrun"
      // There should be a parsed version which is the only time you are allowd to click on it.
      case parse.from_string(code) {
        Ok(source) -> {
          let handlers = dict.new()
          let env = dynamic.unsafe_coerce(dynamic.from(stdlib.env()))
          let assert Ok(f) =
            r.execute(source, env, handlers)
            |> io.debug
          let f = dynamic.unsafe_coerce(dynamic.from(f))
          r.resume(f, [v.unit], stdlib.env(), dict.new())
          |> io.debug
          #(state, effect.none())
        }
        Error(reason) -> {
          io.debug(#("error", reason))
          #(state, effect.none())
        }
      }
    }
    CloseRunner -> {
      let state = State(running: None)
      #(state, effect.none())
    }
  }
}

pub type Effect {
  Log(String)
  Random(Int)
}

pub type Handle {
  Abort(String)
  Waiting
  Asked
  Done
}

pub type Runner {
  Runner(handle: Handle, effects: List(Effect))
}
