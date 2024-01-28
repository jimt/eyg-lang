import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result.{try}
import gleam/string
import glance as g
import scintilla/value.{type Value} as v
import scintilla/reason as r
import scintilla/cast
import scintilla/interpreter/state
import repl/reader

pub type State =
  #(Dict(String, Value), Dict(String, g.Module))

pub fn init(scope, modules) {
  #(scope, modules)
}

// could return bindings not env
pub fn read(term, state) {
  let #(scope, modules) = state
  case term {
    reader.Import(module, binding, unqualified) -> {
      case dict.get(modules, module) {
        Ok(module) -> {
          let scope = dict.insert(scope, binding, v.Module(module))
          let scope =
            list.fold(unqualified, scope, fn(scope, extra) {
              let #(field, name) = extra
              let assert Ok(value) = state.access_module(module, field)
              dict.insert(scope, name, value)
            })
          Ok(#(None, #(scope, modules)))
        }
        Error(Nil) -> {
          Error(r.UnknownModule(module))
        }
      }
    }
    reader.CustomType(variants) -> {
      let scope =
        list.fold(variants, scope, fn(scope, variant) {
          let #(name, fields) = variant
          let value = case fields {
            [] -> v.R(name, [])
            _ -> v.Constructor(name, fields)
          }
          dict.insert(scope, name, value)
        })
      let state = #(scope, modules)
      Ok(#(None, state))
    }
    reader.Constant(name, exp) -> {
      case loop(state.next(state.eval(exp, scope, []))) {
        Ok(value) -> {
          let scope = dict.insert(scope, name, value)
          let state = #(scope, modules)
          Ok(#(Some(value), state))
        }
        Error(#(reason, _, _)) -> Error(reason)
      }
    }
    reader.Function(name, parameters, body) -> {
      let value = v.NamedClosure(parameters, body, scope)
      let scope = dict.insert(scope, name, value)
      let state = #(scope, modules)
      Ok(#(Some(value), state))
    }
    reader.Statements(statements) -> {
      case exec(statements, scope) {
        Ok(value) -> Ok(#(Some(value), state))
        Error(r.Finished(scope)) -> {
          let state = #(scope, modules)
          Ok(#(None, state))
        }
        Error(reason) -> Error(reason)
      }
    }
  }
}

// TODO make eval available

// This should be a list of statements from glance
pub fn exec(statements, env) {
  loop(state.next(state.push_statements(statements, env, [])))
  // TODO remove this error
  |> result.map_error(fn(e: #(_, _, _)) { e.0 })
}

pub fn loop(next) {
  case next {
    state.Loop(c, e, k) -> loop(state.step(c, e, k))
    state.Break(result) -> result
  }
}
