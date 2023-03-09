import gleam/int
import gleam/list
import gleam/map
import gleam/option.{None, Option, Some}
import gleam/string
import lustre/element.{pre, span, text}
import lustre/event.{dispatch, on_click}
import lustre/attribute.{class, classes, style}
import eygir/expression as e
import atelier/app.{SelectNode}
import atelier/view/typ
import eyg/analysis/inference

pub fn render(source, selection, inferred: Option(inference.Infered)) {
  let loc = Location([], Some(selection))
  pre(
    [style([#("cursor", "pointer")]), class("w-full max-w-6xl")],
    do_render(source, "\n", loc, inferred),
  )
}

fn click(loc: Location) {
  on_click(dispatch(SelectNode(loc.path)))
}

pub fn do_render(exp, br, loc, inferred) {
  case exp {
    e.Variable(var) -> [variable(var, loc, inferred)]
    e.Lambda(param, body) -> [lambda(param, body, br, loc, inferred)]
    e.Apply(func, arg) -> call(func, arg, br, loc, inferred)
    e.Let(label, value, then) ->
      assigment(label, value, then, br, loc, inferred)
    e.Binary(value) -> [string(value, loc, inferred)]
    e.Integer(value) -> [integer(value, loc, inferred)]
    e.Tail -> [
      span(
        [click(loc), classes(highlight(focused(loc), error(loc, inferred)))],
        [text("[]")],
      ),
    ]
    e.Cons -> [
      // maybe gray but probably better rendering in apply
      span(
        [
          click(loc),
          classes([
            #("text-gray-400", True),
            ..highlight(focused(loc), error(loc, inferred))
          ]),
        ],
        [text("cons")],
      ),
    ]
    e.Vacant -> [vacant(loc, inferred)]
    e.Empty -> [
      span(
        [click(loc), classes(highlight(focused(loc), error(loc, inferred)))],
        [text("{}")],
      ),
    ]
    e.Extend(label) -> [extend(label, loc, inferred)]
    e.Select(label) -> [select(label, loc, inferred)]
    e.Overwrite(label) -> [overwrite(label, loc, inferred)]
    e.Tag(label) -> [tag(label, loc, inferred)]
    e.Case(label) -> [match(label, br, loc, inferred)]
    e.NoCases -> [
      span(
        [
          click(loc),
          classes([
            #("text-gray-400", True),
            ..highlight(focused(loc), error(loc, inferred))
          ]),
        ],
        [text("nocases")],
      ),
    ]
    e.Perform(label) -> [perform(label, loc, inferred)]
    e.Handle(label) -> [handle(label, loc, inferred)]
    e.Builtin(id) -> [variable(id, loc, inferred)]
  }
}

fn render_block(exp, br, loc, inferred) {
  case exp {
    e.Let(_, _, _) ->
      case open(loc) {
        True -> {
          let br_inner = string.append(br, "  ")
          list.flatten([
            [text(string.append("{", br_inner))],
            do_render(exp, br_inner, loc, inferred),
            [text(string.append(br, "}"))],
          ])
        }
        False -> [span([click(loc)], [text("{ ... }")])]
      }
    _ -> do_render(exp, br, loc, inferred)
  }
}

fn highlight(target, alert) {
  // let colour = case target, alert {
  //   True, _ -> [#("border-b-2", True), #("border-indigo-300", True)]
  //   _, True -> [#("border-b-2", False), #("bg-red-100", True)]
  //   False, False -> [#("border-b-2", False), #("border-indigo-300", True)]
  // }
  [
    #("border-b-2", target),
    #("border-indigo-300", True),
    #("rounded", True),
    #("bg-red-200", alert),
  ]
}

fn variable(var, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)

  [classes(highlight(target, alert)), click(loc)]
  |> span([text(var)])
}

fn lambda(param, body, br, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)

  [classes(highlight(target, alert))]
  |> span([
    span([click(loc)], [text(param), text(" -> ")]),
    ..render_block(body, br, child(loc, 0), inferred)
  ])
}

fn render_branch(label, then, else, br, loc_branch, loc_else, inferred) {
  let loc_match = child(loc_branch, 0)
  let loc_then = child(loc_branch, 1)
  let match =
    [
      click(loc_match),
      classes([
        #("text-blue-500", True),
        ..highlight(focused(loc_match), error(loc_match, inferred))
      ]),
    ]
    |> span([text(label)])
  let branch = render_block(then, br, loc_then, inferred)
  [
    text(br),
    span(
      [classes(highlight(focused(loc_branch), error(loc_branch, inferred)))],
      [match, text(" "), ..branch],
    ),
    ..case else {
      e.NoCases -> [
        text(br),
        span([class("text-gray-400"), click(loc_else)], [text("-- closed --")]),
      ]
      e.Apply(e.Apply(e.Case(label), then), else) ->
        render_branch(
          label,
          then,
          else,
          br,
          child(loc_else, 0),
          child(loc_else, 1),
          inferred,
        )
      _ -> [text(br), ..do_render(else, br, loc_else, inferred)]
    }
  ]
}

// case can only be applied with literal or var to correct things
// call with binary is error
// apply to just a case could leave it as ++
// nocases should be rendered alone as empty match
fn call(func, arg, br, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)

  // not target but any selected
  let inner = case func, arg {
    // e.Apply(e.Case(label), then) -> {
    //   let loc_branch = child(loc, 0)
    //   let loc_else = child(loc, 1)
    //   case open(loc_branch) || open(loc_else) {
    //     True -> {
    //       let pre = [
    //         span(
    //           [click(loc)],
    //           [span([class("text-gray-400")], [text("match")]), text(" {")],
    //         ),
    //       ]
    //       let branches =
    //         render_branch(
    //           label,
    //           then,
    //           arg,
    //           string.append(br, "  "),
    //           loc_branch,
    //           loc_else,
    //         )
    //       let post = [text(br), text("}")]
    //       list.flatten([pre, branches, post])
    //     }
    //     False -> [
    //       span(
    //         [click(loc_branch)],
    //         [span([class("text-gray-400")], [text("match")]), text(" { ... }")],
    //       ),
    //     ]
    //   }
    // }
    e.Apply(e.Extend(label), element), arg ->
      list.flatten([
        [
          text("{"),
          span(
            {
              let loc = child(child(loc, 0), 0)
              [
                click(loc),
                classes([
                  #("text-blue-700", True),
                  ..highlight(focused(loc), error(loc, inferred))
                ]),
              ]
            },
            [text(label)],
          ),
          text(": "),
        ],
        render_block(element, br, child(child(loc, 0), 1), inferred),
        [text(", ")],
        render_block(arg, br, child(loc, 1), inferred),
        [text("}")],
      ])
    e.Apply(e.Cons, element), arg ->
      list.flatten([
        [text("[")],
        render_block(element, br, child(child(loc, 0), 1), inferred),
        [text(", ")],
        render_block(arg, br, child(loc, 1), inferred),
        [text("]")],
      ])
    e.Select(_), arg ->
      list.flatten([
        render_block(arg, br, child(loc, 1), inferred),
        render_block(func, br, child(loc, 0), inferred),
      ])
    _, arg ->
      // arg becomes then
      list.flatten([
        render_block(func, br, child(loc, 0), inferred),
        [text("(")],
        render_block(arg, br, child(loc, 1), inferred),
        [text(")")],
      ])
  }

  [span([classes(highlight(target, alert))], inner)]
}

fn assigment(label, value, then, br, loc, inferred) {
  let active = focused(loc)
  let alert = error(loc, inferred)

  let assignment = [
    span(
      [click(loc)],
      [span([class("text-gray-400")], [text("let ")]), text(label), text(" = ")],
    ),
    ..render_block(value, br, child(loc, 0), inferred)
  ]
  let el = span([classes(highlight(active, alert))], assignment)
  [el, text(br), ..do_render(then, br, child(loc, 1), inferred)]
}

fn error(loc: Location, inferred: Option(inference.Infered)) {
  case inferred {
    Some(inferred) ->
      case map.get(inferred.types, loc.path) {
        Ok(Error(_)) -> True
        _ -> False
      }
    None -> False
  }
}

fn string(value, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)
  let value = case string.split_once(value, "\n") {
    Error(Nil) -> value
    Ok(#(head, _)) -> string.append(head, "...")
  }
  let content = string.concat(["\"", value, "\""])
  [click(loc), classes([#("text-green-500", True), ..highlight(target, alert)])]
  |> span([text(content)])
}

fn integer(value, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)
  [
    click(loc),
    classes([#("text-purple-500", True), ..highlight(target, alert)]),
  ]
  |> span([text(int.to_string(value))])
}

fn vacant(loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)
  let content = case inferred {
    Some(inferred) -> typ.render(inference.type_of(inferred, loc.path))
    None -> "todo"
  }
  [click(loc), classes([#("text-red-500", True), ..highlight(target, alert)])]
  |> span([text(content)])
}

fn extend(label, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)

  [click(loc), classes([#("text-blue-700", True), ..highlight(target, alert)])]
  |> span([text(string.append("+", label))])
}

fn select(label, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)

  [click(loc), classes([#("text-blue-700", True), ..highlight(target, alert)])]
  |> span([text(string.append(".", label))])
}

fn overwrite(label, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)

  [click(loc), classes([#("text-blue-700", True), ..highlight(target, alert)])]
  |> span([text(string.append(":=", label))])
}

fn tag(label, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)

  [click(loc), classes([#("text-blue-500", True), ..highlight(target, alert)])]
  |> span([text(label)])
}

fn match(label, _br, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)

  [click(loc), classes([#("text-blue-500", True), ..highlight(target, alert)])]
  |> span([text(label)])
}

fn perform(label, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)

  [click(loc), classes(highlight(target, alert))]
  |> span([span([class("text-gray-400")], [text("perform ")]), text(label)])
}

fn handle(label, loc, inferred) {
  let target = focused(loc)
  let alert = error(loc, inferred)

  [click(loc), classes(highlight(target, alert))]
  |> span([span([class("text-gray-400")], [text("handle ")]), text(label)])
}

// location is separate to path, extract but it may be view layer only.
pub type Location {
  Location(path: List(Int), selection: Option(List(Int)))
}

fn open(location) {
  let Location(selection: selection, ..) = location
  case selection {
    None -> False
    Some(_) -> True
  }
}

fn focused(location) {
  let Location(selection: selection, ..) = location
  case selection {
    Some([]) -> True
    _ -> False
  }
}

// call location.step
fn child(location, i) {
  let Location(path: path, selection: selection) = location
  let path = list.append(path, [i])
  let selection = case selection {
    Some([j, ..inner]) if i == j -> Some(inner)
    _ -> None
  }
  Location(path, selection)
}
