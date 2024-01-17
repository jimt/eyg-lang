import gleam/list
import gleam/dict.{type Dict}
import gleam/result
import eygir/expression as e
import gleam/javascript/promise
import eyg/runtime/value as v
import eyg/runtime/break
import eyg/runtime/cast

pub type Context =
  #(List(Kontinue), Path, Env)

pub type Value =
  v.Value(Context)

pub type Reason =
  break.Reason(Context)

pub type Control {
  E(e.Expression)
  V(Value)
}

pub type Next {
  Loop(Control, Path, Env, Stack)
  Break(Result(Value, #(Reason, Path, Env, Stack)))
}

pub type Path =
  List(Int)

// Env and Stack also rely on each other
pub type Env {
  Env(scope: List(#(String, Value)), builtins: dict.Dict(String, Builtin))
}

pub type Return =
  Result(#(Control, Path, Env, Stack), Reason)

pub type Builtin {
  Arity1(fn(Value, Path, Env, Stack) -> Return)
  Arity2(fn(Value, Value, Path, Env, Stack) -> Return)
  Arity3(fn(Value, Value, Value, Path, Env, Stack) -> Return)
}

pub type Stack {
  Stack(Kontinue, Stack)
  Empty(Dict(String, Extrinsic))
}

pub type Kontinue {
  Arg(e.Expression, Path, Path, Env)
  Apply(Value, Path, Env)
  Assign(String, e.Expression, Path, Env)
  CallWith(Value, Path, Env)
  Delimit(String, Value, Path, Env, Bool)
}

pub type Extrinsic =
  fn(Value) -> Result(Value, Reason)

// loop and eval go to runner as you'd build a new one
pub fn eval(exp, env, k) {
  loop(try(do_eval(exp, [], env, k)))
}

// TODO potentially remove, or accept multiple arguments
pub fn eval_call(f, arg, env, k) {
  loop(try(apply(f, [], env, CallWith(arg, [], env), k)))
}

// Solves the situation that JavaScript suffers from coloured functions
// To eval code that may be async needs to return a promise of a result
pub fn await(ret) {
  case ret {
    Error(#(break.UnhandledEffect("Await", v.Promise(p)), rev, env, k)) -> {
      use return <- promise.await(p)
      await(loop(step(V(return), rev, env, k)))
    }
    other -> promise.resolve(other)
  }
}

pub fn loop(next) {
  case next {
    Loop(c, rev, e, k) -> loop(step(c, rev, e, k))
    Break(result) -> result
  }
}

pub fn step(c, rev, env, k) {
  case c, k {
    E(exp), k -> try(do_eval(exp, rev, env, k))
    V(value), Empty(_) -> Break(Ok(value))
    V(value), Stack(k, rest) -> try(apply(value, rev, env, k, rest))
  }
}

fn try(return) {
  case return {
    Ok(#(c, rev, e, k)) -> Loop(c, rev, e, k)
    Error(info) -> Break(Error(info))
  }
}

fn do_eval(exp, rev, env: Env, k) {
  let value = fn(value) { Ok(#(V(value), rev, env, k)) }
  case exp {
    e.Lambda(param, body) ->
      Ok(#(V(v.Closure(param, body, env.scope, rev)), rev, env, k))

    e.Apply(f, arg) ->
      Ok(#(E(f), [0, ..rev], env, Stack(Arg(arg, [1, ..rev], rev, env), k)))

    e.Variable(x) ->
      case list.key_find(env.scope, x) {
        Ok(term) -> Ok(#(V(term), rev, env, k))
        Error(Nil) -> Error(break.UndefinedVariable(x))
      }

    e.Let(var, value, then) -> {
      let k = Stack(Assign(var, then, [1, ..rev], env), k)
      Ok(#(E(value), [0, ..rev], env, k))
    }

    e.Binary(data) -> value(v.Binary(data))
    e.Integer(data) -> value(v.Integer(data))
    e.Str(data) -> value(v.Str(data))
    e.Tail -> value(v.LinkedList([]))
    e.Cons -> value(v.Partial(v.Cons, []))
    e.Vacant(comment) -> Error(break.Vacant(comment))
    e.Select(label) -> value(v.Partial(v.Select(label), []))
    e.Tag(label) -> value(v.Partial(v.Tag(label), []))
    e.Perform(label) -> value(v.Partial(v.Perform(label), []))
    e.Empty -> value(v.unit)
    e.Extend(label) -> value(v.Partial(v.Extend(label), []))
    e.Overwrite(label) -> value(v.Partial(v.Overwrite(label), []))
    e.Case(label) -> value(v.Partial(v.Match(label), []))
    e.NoCases -> value(v.Partial(v.NoCases, []))
    e.Handle(label) -> value(v.Partial(v.Handle(label), []))
    e.Shallow(label) -> value(v.Partial(v.Shallow(label), []))
    e.Builtin(identifier) -> value(v.Partial(v.Builtin(identifier), []))
  }
  |> result.map_error(fn(reason) { #(reason, rev, env, k) })
}

fn apply(value, rev, env, k, rest) {
  case k {
    Assign(label, then, rev, env) -> {
      let env = Env(..env, scope: [#(label, value), ..env.scope])
      Ok(#(E(then), rev, env, rest))
    }
    Arg(arg, rev, call_rev, env) ->
      Ok(#(E(arg), rev, env, Stack(Apply(value, call_rev, env), rest)))
    Apply(f, rev, env) -> step_call(f, value, rev, env, rest)
    CallWith(arg, rev, env) -> step_call(value, arg, rev, env, rest)
    Delimit(_, _, _, _, _) -> Ok(#(V(value), rev, env, rest))
  }
  |> result.map_error(fn(reason) { #(reason, rev, env, Stack(k, rest)) })
}

pub fn step_call(f, arg, rev, env: Env, k: Stack) {
  case f {
    v.Closure(param, body, captured, rev) -> {
      let env = Env(..env, scope: [#(param, arg), ..captured])
      Ok(#(E(body), rev, env, k))
    }
    // builtin needs to return result for the case statement
    // Resume/Shallow/Deep need access to k nothing needs access to env but extension might change that
    v.Partial(switch, applied) ->
      case switch, applied {
        v.Cons, [item] -> {
          use elements <- result.then(cast.as_list(arg))
          Ok(#(V(v.LinkedList([item, ..elements])), rev, env, k))
        }
        v.Extend(label), [value] -> {
          use fields <- result.then(cast.as_record(arg))
          Ok(#(V(v.Record([#(label, value), ..fields])), rev, env, k))
        }
        v.Overwrite(label), [value] -> {
          use fields <- result.then(cast.as_record(arg))
          use #(_, fields) <- result.then(
            list.key_pop(fields, label)
            |> result.replace_error(break.MissingField(label)),
          )
          Ok(#(V(v.Record([#(label, value), ..fields])), rev, env, k))
        }
        v.Select(label), [] -> {
          use fields <- result.then(cast.as_record(arg))
          use value <- result.then(
            list.key_find(fields, label)
            |> result.replace_error(break.MissingField(label)),
          )
          Ok(#(V(value), rev, env, k))
        }
        v.Tag(label), [] -> Ok(#(V(v.Tagged(label, arg)), rev, env, k))
        v.Match(label), [branch, otherwise] -> {
          use #(l, inner) <- result.then(cast.as_tagged(arg))
          case l == label {
            True -> step_call(branch, inner, rev, env, k)
            False -> step_call(otherwise, arg, rev, env, k)
          }
        }
        v.NoCases, [] -> Error(break.NoMatch(arg))
        v.Perform(label), [] -> perform(label, arg, rev, env, k)
        v.Handle(label), [handler] -> deep(label, handler, arg, rev, env, k)
        v.Resume(#(popped, rev, env)), [] ->
          Ok(#(V(arg), rev, env, move(popped, k)))
        v.Shallow(label), [handler] -> shallow(label, handler, arg, rev, env, k)
        v.Builtin(key), applied ->
          call_builtin(key, list.append(applied, [arg]), rev, env, k)

        switch, _ -> {
          let applied = list.append(applied, [arg])
          Ok(#(V(v.Partial(switch, applied)), rev, env, k))
        }
      }

    term -> Error(break.NotAFunction(term))
  }
}

// can return a expression body
fn call_builtin(key, applied, rev, env: Env, kont) {
  case dict.get(env.builtins, key) {
    Ok(func) ->
      case func, applied {
        // impl uses path to build stack when calling functions passed in
        // might not need it as fn's keep track of path
        Arity1(impl), [x] -> impl(x, rev, env, kont)
        Arity2(impl), [x, y] -> impl(x, y, rev, env, kont)
        Arity3(impl), [x, y, z] -> impl(x, y, z, rev, env, kont)
        _, _args -> Ok(#(V(v.Partial(v.Builtin(key), applied)), rev, env, kont))
      }
    Error(Nil) -> Error(break.UndefinedVariable(key))
  }
}

// In interpreter because circular dependencies interpreter -> spec -> stdlib/linked list

fn move(delimited, acc) {
  case delimited {
    [] -> acc
    [step, ..rest] -> move(rest, Stack(step, acc))
  }
}

fn do_perform(label, arg, i_rev, i_env, k, acc) {
  case k {
    Stack(Delimit(l, h, rev, e, shallow), rest) if l == label -> {
      let acc = case shallow {
        True -> acc
        False -> [Delimit(label, h, rev, e, False), ..acc]
      }
      let resume = v.Partial(v.Resume(#(acc, i_rev, i_env)), [])
      let k =
        Stack(CallWith(arg, rev, e), Stack(CallWith(resume, rev, e), rest))
      Ok(#(V(h), rev, e, k))
    }
    Stack(kontinue, rest) ->
      do_perform(label, arg, i_rev, i_env, rest, [kontinue, ..acc])
    Empty(extrinsic) -> {
      // inefficient to move back in error case
      let original_k = move(acc, Empty(dict.new()))
      case dict.get(extrinsic, label) {
        Ok(handler) ->
          case handler(arg) {
            Ok(term) -> Ok(#(V(term), i_rev, i_env, original_k))
            Error(reason) -> Error(reason)
          }
        Error(Nil) -> Error(break.UnhandledEffect(label, arg))
      }
    }
  }
}

pub fn perform(label, arg, i_rev, i_env, k: Stack) {
  do_perform(label, arg, i_rev, i_env, k, [])
}

// rename handle and move the handle for runner with handles out
pub fn deep(label, handle, exec, rev, env, k) {
  let k = Stack(Delimit(label, handle, rev, env, False), k)
  step_call(exec, v.unit, rev, env, k)
}

// somewhere this needs outer k
fn shallow(label, handle, exec, rev, env: Env, k) {
  let k = Stack(Delimit(label, handle, rev, env, True), k)
  step_call(exec, v.unit, rev, env, k)
}
