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
      let run = case r.execute(source, env, handlers) {
        Ok(f) -> {
          let f = dynamic.unsafe_coerce(dynamic.from(f))
          let run =
            handle_next(r.resume(f, [v.unit], stdlib.env(), dict.new()), [])
        }
        Error(#(reason, meta, env, k)) -> {
          Runner(Abort(break.reason_to_string(reason)), [])
        }
      }
      let state = State(..state, running: Some(run))
      #(state, effect.none())
    }
    Resume(value, env, k, effects) -> {
      // r.resume(k, [value], env, dict.new())
      let value = dynamic.unsafe_coerce(dynamic.from(value))
      let result = r.loop(istate.step(istate.V(value), env, k))
      let run = handle_next(result, effects)
      let state = State(..state, running: Some(run))
      #(state, effect.none())
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
              Runner(Asking(question, "", env, k), effects)
            }
            "Log" -> {
              let assert Ok(message) = cast.as_string(lift)
              let effects = [Log(message), ..effects]
              r.loop(istate.step(istate.V(v.unit), env, k))
              |> handle_next(effects)
            }
            other -> Runner(Abort(break.reason_to_string(reason)), effects)
          }
        reason -> Runner(Abort(break.reason_to_string(reason)), effects)
      }
    Ok(value) ->
      Runner(Done(dynamic.unsafe_coerce(dynamic.from(value))), effects)
  }
}

pub type Effect {
  Log(String)
  Asked(question: String, answer: String)
  Random(Int)
}

pub type Handle {
  Abort(String)
  Waiting
  Asking(question: String, value: String, Env(Nil), Stack(Nil))
  Done(v.Value(Nil, Nil))
}

pub type Runner {
  Runner(handle: Handle, effects: List(Effect))
}
