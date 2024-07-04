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
import gleam/bit_array
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/int
import gleam/io
import gleam/javascript/promise
import gleam/list
import gleam/result.{try}
import gleam/string
import harness/stdlib

// import plinth/browser/crypto/subtle

type Value =
  v.Value(Span, #(List(#(istate.Kontinue(Span), Span)), Env(Span)))

type BreakReason =
  break.Reason(Span, #(List(#(istate.Kontinue(Span), Span)), Env(Span)))

pub type Referenced {
  Referenced(count: Int, values: Dict(String, Value), types: Dict(String, Poly))
}

pub type State {
  State(scope: List(#(String, Result(String, Nil))), referenced: Referenced)
}

pub type Document(a) {
  Document(
    hash: String,
    scope: List(#(String, Result(String, Nil))),
    sections: List(Snippet(a)),
  )
}

pub type Snippet(c) {
  Snippet(context: c, code: String, processed: Result(Processed, parser.Reason))
}

pub type Processed {
  // line number and reference
  Processed(
    // source: String,
    assignments: List(#(Int, Result(String, BreakReason))),
    errors: List(#(error.Reason, Span)),
    final: State,
  )
}

@external(javascript, "../browser_ffi.mjs", "hashCode")
pub fn hash_code(str: String) -> String

pub fn hash(expression) {
  let expression = annotated.drop_annotation(expression)
  // subtle.digest(<<string.inspect(expression):utf8>>)
  // |> promise.map(io.debug)
  // |> promise.map(result.unwrap(_, <<>>))
  // |> promise.map(bit_array.base16_encode(_))
  // |> promise.map(io.debug)
  hash_code(string.inspect(expression))
}

pub fn empty() {
  Referenced(0, dict.new(), dict.new())
}

pub fn process_new(sections) {
  process(sections, empty())
}

fn do_process_document(sections, references) {
  list.map_fold(sections, State([], references), fn(acc, section) {
    let #(context, code) = section
    let #(acc, processed) = process_snippet(acc, code)
    #(acc, Snippet(context, code, processed))
  })
}

pub fn document_to_code(sections, references) {
  let #(State(scope, _references), sections) =
    do_process_document(sections, references)
  let total = global(scope, sections)
  let ref = "h" <> hash(total)
  #(ref, annotated.drop_annotation(total))
}

pub fn reprocess_document(document: Document(_), references) {
  list.map(document.sections, fn(section) { #(section.context, section.code) })
  |> process_document(references)
}

pub fn process_document(sections, references) {
  let #(State(scope, references), sections) =
    do_process_document(sections, references)

  build(scope, sections, references)
}

pub fn missing_references(doc) {
  let Document(_hash, _scope, sections) = doc
  list.flat_map(sections, fn(section) {
    let Snippet(_, _, processed) = section
    missing_references_per_section(processed)
  })
}

// scope works up from last
fn do_gather_public(scope, acc) {
  case scope {
    [] -> acc
    [#(label, Ok(_)), ..rest] ->
      case list.contains(acc, label) {
        True -> do_gather_public(rest, acc)
        False -> do_gather_public(rest, [label, ..acc])
      }
    [_, ..rest] -> do_gather_public(rest, acc)
  }
}

pub fn external_assigns(document) {
  let Document(_hash, scope, _sections) = document
  do_gather_public(scope, [])
}

pub fn global(scope, sections: List(Snippet(_))) {
  let exports =
    do_gather_public(scope, [])
    |> list.reverse()
    |> list.fold(#(annotated.Empty, #(0, 0)), fn(acc, label) {
      #(
        annotated.Apply(
          #(
            annotated.Apply(
              #(annotated.Extend(label), #(0, 0)),
              #(annotated.Variable(label), #(0, 0)),
            ),
            #(0, 0),
          ),
          acc,
        ),
        #(0, 0),
      )
    })

  let reversed =
    list.filter_map(sections, fn(section) {
      use #(#(assignments, _tail), _rest) <- try(parse.block_from_string(
        section.code,
      ))
      Ok(assignments)
    })
    |> list.reverse
    |> list.flatten()

  list.fold(reversed, exports, fn(acc, assign) {
    let #(label, value, span) = assign
    #(annotated.Let(label, value, acc), span)
  })
}

fn build(scope, sections, references) {
  let total = global(scope, sections)
  let #(new_errors, result) = install_code(references, [], total)
  let #(ref, references) = case result {
    Ok(#(ref, references)) -> #(ref, references)
    Error(_) -> #("", references)
  }
  #(Document(ref, scope, sections), references)
}

pub fn update_at(document, index, new, references) {
  let Document(_hash, _scope, sections) = document
  let #(pre, post) = list.split(sections, index)
  let scope =
    list.reverse(pre)
    |> list.find_map(fn(section) {
      let Snippet(_, _, snippet) = section
      case snippet {
        Ok(Processed(final: State(scope: scope, ..), ..)) -> Ok(scope)
        Error(_) -> Error(Nil)
      }
    })
    |> result.unwrap([])
  let post = case post {
    [Snippet(context, _old, _drop_cache), ..rest] -> [
      #(context, new),
      ..list.map(rest, fn(s) { #(s.context, s.code) })
    ]
    [] -> {
      panic as "out of range"
      // [#(h.div([], [element.text("new section")]), new)]
    }
  }
  let #(State(scope, references), post) =
    list.map_fold(post, State(scope, references), fn(acc, section) {
      let #(context, code) = section
      let #(acc, snippet) = process_snippet(acc, code)
      #(acc, Snippet(context, code, snippet))
    })
  let sections = list.append(pre, post)
  build(scope, sections, references)
}

pub fn process(sections, referenced) {
  let state = State([], referenced)

  // return full state as we will use that for the hash for the whole page
  list.map_fold(sections, state, process_snippet)
}

pub fn process_snippet(state, code) {
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

          let expression = annotated.substitute_for_references(expression, subs)

          let #(new_errors, result) = install_code(referenced, env, expression)
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
      #(state, Ok(Processed(assignments, errors, state)))
    }
  }
}

fn missing_references_per_section(r) {
  case r {
    Ok(Processed(errors: errors, ..)) -> {
      io.debug(errors)
      list.filter_map(errors, fn(error) {
        let #(reason, _span) = error
        case reason {
          error.MissingVariable("#" <> ref) -> Ok(ref)
          _ -> Error(Nil)
        }
      })
    }
    _ -> []
  }
}

pub fn install_code(acc, type_env, expression) {
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
    let ref = "h" <> hash(expression)

    // if expression evaluates we don't need to worry about eff
    // because evaluation is pure it will always be the same value
    // typechecking at the top should always be ok
    let #(_res, typevar, _eff, _env) = type_info
    let top_type = binding.gen(typevar, -1, bindings)

    // TODO remove ref
    // let ref = "i" <> int.to_string(count)
    // let count = count + 1

    let values = dict.insert(values, ref, value)
    let types = dict.insert(types, ref, top_type)
    let acc = Referenced(count, values, types)
    Ok(#(ref, acc))
  })
}
