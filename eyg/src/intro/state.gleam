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

pub type State {
  State(sections: List(#(Element(Message), String)), running: Option(Runner))
}

pub fn init(_) {
  let state = State(content.sections(), None)
  #(state, effect.none())
}

pub type Message {
  EditCode(sections: List(#(Element(Message), String)))
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
    Run(source) -> {
      let handlers = dict.new()
      let env = dynamic.unsafe_coerce(dynamic.from(stdlib.env()))
      let assert Ok(f) = r.execute(source, env, handlers)
      let f = dynamic.unsafe_coerce(dynamic.from(f))
      let run = case r.resume(f, [v.unit], stdlib.env(), dict.new()) {
        Error(#(reason, meta, env, k)) ->
          case reason {
            break.UnhandledEffect(label, lift) ->
              case label {
                "Ask" -> {
                  let assert Ok(question) = cast.as_string(lift)
                  Runner(Asking(question, env, k), [])
                }
                other -> Runner(Abort(break.reason_to_string(reason)), [])
              }
            reason -> Runner(Abort(break.reason_to_string(reason)), [])
          }
        Ok(value) -> Runner(Done(dynamic.unsafe_coerce(dynamic.from(f))), [])
      }
      let state = State(..state, running: Some(run))
      #(state, effect.none())
    }
    Resume(value, env, k, effects) -> {
      // r.resume(k, [value], env, dict.new())
      let value = dynamic.unsafe_coerce(dynamic.from(value))
      r.loop(istate.step(istate.V(value), env, k))
      |> io.debug()
      todo as "resummsdfdf"
    }
    CloseRunner -> {
      let state = State(..state, running: None)
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
  Asking(String, Env(Nil), Stack(Nil))
  Done(v.Value(Nil, Nil))
}

pub type Runner {
  Runner(handle: Handle, effects: List(Effect))
}
