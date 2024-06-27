import eyg/analysis/inference/levels_j/contextual as j
import eyg/analysis/type_/binding.{type Poly}
import eyg/analysis/type_/isomorphic as t
import eyg/parse
import eyg/runtime/interpreter/runner as r
import eyg/runtime/interpreter/state.{type Env, type Stack} as istate
import eyg/runtime/value as v
import eyg/text/text
import eygir/annotated
import eygir/expression as e
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import gleeunit/should
import harness/stdlib

// TODO put hightlight all on one layer -> parsing followed by type errors

type Value =
  v.Value(
    #(Int, Int),
    #(List(#(istate.Kontinue(#(Int, Int)), #(Int, Int))), Env(#(Int, Int))),
  )

type Referenced {
  Referenced(
    count: Int,
    reference_values: Dict(String, Value),
    reference_types: Dict(String, Poly),
  )
}

type State {
  State(scope: List(#(String, String)), referenced: Referenced)
}

fn empty() {
  Referenced(0, dict.new(), dict.new())
}

fn new_state() {
  State([], empty())
}

fn process_new(sections) {
  process(sections, new_state())
}

fn process(sections, state) {
  list.map_fold(sections, state, fn(acc, code) {
    // let State(scope, count, references) = acc
    case parse.block_from_string(code) {
      Error(reason) -> #(acc, Error(reason))
      Ok(#(#(assignments, then), _tokens)) -> {
        let assignments = list.reverse(assignments)

        let #(acc, assignments) =
          list.map_fold(assignments, acc, fn(acc, assignment) {
            let State(scope, referenced) = acc
            let #(label, expression, span) = assignment

            let #(start, _) = span
            let line_number = text.offset_line_number(code, start)

            let expression =
              annotated.substitute_for_references(expression, scope)

            let #(ref, referenced) = install_code(referenced, expression)

            // case ok errors on acc
            // accumulate all the errors
            // need to add an any var to the scope incases it doesn't work out
            let acc = State([#(label, ref), ..scope], referenced)
            #(acc, #(line_number, ref))
          })

        // TODO state for resumption
        // TODO type errors
        #(acc, Ok(assignments))
      }
    }
  })
}

fn install_code(acc, expression) {
  let Referenced(count, values, types) = acc
  let env =
    istate.Env(
      // only safe to coerce because all values are builtins
      ..stdlib.env()
      |> dynamic.from()
      |> dynamic.unsafe_coerce(),
      references: values,
    )

  let handlers = dict.new()
  let assert Ok(value) = r.execute(expression, env, handlers)
  let ast = annotated.drop_annotation(expression)
  let #(exp, bindings) = j.infer(ast, t.Empty, types, 0, j.new_state())

  let #(_, type_info) = exp
  // if expression evaluates we don't need to worry about eff
  // because evaluation is pure it will always be the same value
  // typechecking at the top should always be ok
  let #(_res, typevar, _eff, _env) = type_info
  let poly = binding.gen(typevar, -1, bindings)

  let ref = "i" <> int.to_string(count)
  let count = count + 1

  let values = dict.insert(values, ref, value)
  let types = dict.insert(types, ref, poly)
  let acc = Referenced(count, values, types)
  #(ref, acc)
}

pub fn simple_assignments_test() {
  let code =
    "let x = 1
  let y = {}"
  let #(acc, sections) = process_new([code])

  let State(_, referenced) = acc
  let Referenced(_, values, types) = referenced
  let assert [section] = sections
  let assert Ok([#(1, ref_x), #(2, ref_y)]) = section

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

  let assert [section] = sections
  let assert Ok([#(1, ref_x), #(2, ref_y)]) = section

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
  let #(ref, referenced) = install_code(empty(), pre)

  let code = "let a = {foo: #foo}" |> string.replace("#foo", "#" <> ref)

  let #(acc, sections) = process([code], State([], referenced))

  let State(_, referenced) = acc
  let Referenced(_, values, types) = referenced

  let assert [section] = sections
  let assert Ok([#(1, ref_a)]) = section |> io.debug

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

  Nil
}

// collect type errors
// run functions

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

// find all references
// eval
// typecheck
// reference -> poly + value
// get the line information
// run a hash so value called with term ->
//  and hash for whole type for whole 

pub fn type_check_test() {
  let tree = e.Let("x", e.Variable("a"), e.Variable("x"))
  let references = dict.new()

  let #(exp, bindings) = j.infer(tree, t.Empty, references, 0, j.new_state())

  let #(_, type_info) = exp
  let #(_res, typevar, _eff, _hmm) = type_info

  let poly = binding.gen(typevar, -1, bindings)
  // io.debug(poly)
  // assert is totally generalised

  let tree =
    e.Let(
      "x",
      e.Variable("a"),
      e.Let("x", e.Lambda("arg", e.Variable("arg")), e.Variable("x")),
    )
  let references = dict.new()

  let #(exp, bindings) = j.infer(tree, t.Empty, references, 0, j.new_state())

  let #(_, type_info) = exp
  let #(_res, typevar, _eff, _hmm) = type_info

  let poly = binding.gen(typevar, -1, bindings)
  // fully qualified

  // io.debug(poly)
}
