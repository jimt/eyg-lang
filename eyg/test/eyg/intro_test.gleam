import eyg/analysis/inference/levels_j/contextual as j
import eyg/analysis/type_/binding.{type Poly}
import eyg/analysis/type_/binding/error
import eyg/analysis/type_/isomorphic as t
import eyg/parse
import eyg/parse/parser.{type Span}
import eyg/runtime/break
import eyg/runtime/interpreter/runner as r
import eyg/runtime/interpreter/state.{type Env} as istate
import eyg/runtime/value as v
import eyg/text/text
import eygir/annotated
import eygir/expression as e
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/int
import gleam/io
import gleam/list
import gleam/result.{try}
import gleam/string
import gleeunit/should
import harness/stdlib

// TODO find all references ahead of time
// TODO put hightlight all on one layer -> parsing followed by type errors
// Always eval ref in empty environment
// TODO maybe cache should be before the block
// // TODO references in source code are red when errored
// TODO run functions
// create a block type as returned can have before and after
// is it worth keeping results in returned assigns maybe show why can't run and highlight errors in the span
// share button

type Value =
  v.Value(Span, #(List(#(istate.Kontinue(Span), Span)), Env(Span)))

type BreakReason =
  break.Reason(Span, #(List(#(istate.Kontinue(Span), Span)), Env(Span)))

pub type Referenced {
  Referenced(
    count: Int,
    reference_values: Dict(String, Value),
    reference_types: Dict(String, Poly),
  )
}

pub type State {
  State(scope: List(#(String, Result(String, Nil))), referenced: Referenced)
}

pub type Snippet {
  // line number and reference
  Snippet(
    source: String,
    assignments: List(#(Int, Result(String, BreakReason))),
    errors: List(#(error.Reason, Span)),
    final: State,
  )
}

fn empty() {
  Referenced(0, dict.new(), dict.new())
}

fn process_new(sections) {
  process(sections, empty())
}

fn process(sections, referenced) {
  let state = State([], referenced)

  // return full state as we will use that for the hash for the whole page
  list.map_fold(sections, state, fn(state, code) {
    case parse.block_from_string(code) {
      Error(reason) -> #(state, Error(reason))
      Ok(#(#(assignments, _then), _tokens)) -> {
        let assignments = list.reverse(assignments)

        let acc = #([], state)
        let #(acc, assignments) =
          list.map_fold(assignments, acc, fn(acc, assignment) {
            let #(errors, State(scope, referenced)) = acc
            let #(label, expression, span) = assignment

            let #(start, _) = span
            let line_number = text.offset_line_number(code, start)

            let #(subs, env) =
              list.map(scope, fn(x) {
                case x.1 {
                  Ok(value) -> Ok(#(x.0, value))
                  Error(Nil) -> Error(#(x.0, j.q(0)))
                }
              })
              |> result.partition()

            let expression =
              annotated.substitute_for_references(expression, subs)

            let #(new_errors, result) =
              install_code(referenced, env, expression)
            let errors = list.append(errors, new_errors)
            case result {
              Ok(#(ref, referenced)) -> {
                let scope = [#(label, Ok(ref)), ..scope]
                let acc = #(errors, State(scope, referenced))
                #(acc, #(line_number, Ok(ref)))
              }
              Error(#(reason, _meta, _env, _stack)) -> {
                let scope = [#(label, Error(Nil)), ..scope]
                let acc = #(errors, State(scope, referenced))
                #(acc, #(line_number, Error(reason)))
              }
            }
          })
        let #(errors, state) = acc
        #(state, Ok(Snippet(code, assignments, errors, state)))
      }
    }
  })
}

fn install_code(acc, type_env, expression) {
  let Referenced(count, values, types) = acc
  let env =
    istate.Env(
      // only safe to coerce because all values are builtins
      ..stdlib.env()
      |> dynamic.from()
      |> dynamic.unsafe_coerce(),
      references: values,
    )

  let #(ast, meta) = annotated.strip_annotation(expression)
  let #(bindings, _, _, exp) =
    j.do_infer(ast, type_env, t.Empty, types, 0, j.new_state())

  let #(_, type_info) = exp
  let #(_, info) = annotated.strip_annotation(exp)
  let assert Ok(errors) =
    list.map(info, fn(i) { i.0 })
    |> list.strict_zip(meta)
  let errors =
    errors
    |> list.filter_map(fn(pair) {
      case pair.0 {
        Ok(Nil) -> Error(Nil)
        Error(reason) -> Ok(#(reason, pair.1))
      }
    })

  let handlers = dict.new()
  #(errors, {
    use value <- try(r.execute(expression, env, handlers))

    // if expression evaluates we don't need to worry about eff
    // because evaluation is pure it will always be the same value
    // typechecking at the top should always be ok
    let #(_res, typevar, _eff, _env) = type_info
    let top_type = binding.gen(typevar, -1, bindings)

    let ref = "i" <> int.to_string(count)
    let count = count + 1

    let values = dict.insert(values, ref, value)
    let types = dict.insert(types, ref, top_type)
    let acc = Referenced(count, values, types)
    Ok(#(ref, acc))
  })
}

pub fn simple_assignments_test() {
  let code =
    "let x = 1
  let y = {}"
  let #(acc, sections) = process_new([code])

  let State(_, referenced) = acc
  let Referenced(_, values, types) = referenced
  let assert [snippet] = sections
  let snippet = should.be_ok(snippet)
  should.equal(snippet.errors, [])
  let assert [#(1, Ok(ref_x)), #(2, Ok(ref_y))] = snippet.assignments

  let value_x = should.be_ok(dict.get(values, ref_x))
  should.equal(value_x, v.Integer(1))
  let type_x = should.be_ok(dict.get(types, ref_x))
  should.equal(type_x, t.Integer)

  let value_y = should.be_ok(dict.get(values, ref_y))
  should.equal(value_y, v.unit)
  let type_y = should.be_ok(dict.get(types, ref_y))
  should.equal(type_y, t.unit)
}

pub fn simple_var_test() {
  let code =
    "let z = 1
  let t = z"
  let #(acc, sections) = process_new([code])
  let State(_, referenced) = acc
  let Referenced(_, values, types) = referenced

  let assert [snippet] = sections
  let snippet = should.be_ok(snippet)
  should.equal(snippet.errors, [])
  let assert [#(1, Ok(ref_x)), #(2, Ok(ref_y))] = snippet.assignments

  let value_x = should.be_ok(dict.get(values, ref_x))
  should.equal(value_x, v.Integer(1))
  let type_x = should.be_ok(dict.get(types, ref_x))
  should.equal(type_x, t.Integer)

  let value_y = should.be_ok(dict.get(values, ref_y))
  should.equal(value_y, value_x)
  let type_y = should.be_ok(dict.get(types, ref_y))
  should.equal(type_y, type_x)
}

pub fn known_reference_test() {
  let pre =
    e.Apply(e.Tag("Ok"), e.Integer(2))
    |> annotated.add_annotation(#(0, 0))
  let assert #([], Ok(#(ref, referenced))) = install_code(empty(), [], pre)

  let code = "let a = {foo: #foo}" |> string.replace("#foo", "#" <> ref)

  let #(acc, sections) = process([code], referenced)

  let State(_, referenced) = acc
  let Referenced(_, values, types) = referenced

  let assert [snippet] = sections
  let snippet = should.be_ok(snippet)
  should.equal(snippet.errors, [])
  let assert [#(1, Ok(ref_a))] = snippet.assignments

  let value_a = should.be_ok(dict.get(values, ref_a))
  should.equal(value_a, v.Record([#("foo", v.Tagged("Ok", v.Integer(2)))]))
  let type_a = should.be_ok(dict.get(types, ref_a))
  should.equal(
    type_a,
    t.Record(t.RowExtend(
      "foo",
      t.Union(t.RowExtend("Ok", t.Integer, t.Var(key: #(True, 4)))),
      t.Empty,
    )),
  )
}

pub fn type_error_test() {
  let code = "let f = (_) -> { 3({}) }"
  let #(acc, sections) = process_new([code])
  let State(_, referenced) = acc
  let Referenced(_, values, types) = referenced

  let assert [snippet] = sections
  let snippet = should.be_ok(snippet)
  let assert [#(error.TypeMismatch(_, t.Integer), _span)] = snippet.errors
  let assert [#(1, Ok(ref_f))] = snippet.assignments
  let _value = should.be_ok(dict.get(values, ref_f))
  let _type = should.be_ok(dict.get(types, ref_f))
}

// Test that only the missing variable j is an error as k is something else
pub fn runtime_error_test() {
  let code =
    "let k = j
let l = k"
  let #(acc, sections) = process_new([code])
  let State(_, referenced) = acc
  let Referenced(_, values, types) = referenced

  let assert [snippet] = sections
  let snippet = should.be_ok(snippet)
  let assert [#(error.MissingVariable("j"), _span)] = snippet.errors
  should.equal(dict.size(values), 0)
  should.equal(dict.size(types), 0)
}

fn ref(hash) {
  e.Builtin("#" <> hash)
}

pub fn replace_test() {
  let references = [#("a", "123"), #("x", "234"), #("x", "345")]

  e.Let("x", e.Variable("a"), e.Variable("x"))
  |> annotated.add_annotation(Nil)
  |> annotated.substitute_for_references(references)
  |> annotated.drop_annotation()
  |> should.equal(e.Let("x", ref("123"), e.Variable("x")))
}
