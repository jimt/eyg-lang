import gleam/io
import gleam/int
import gleam/list
import gleam/listx
import gleam/map
import gleam/result
import gleam/regex
import gleam/string
import gleam/stringx
import eygir/expression as e
import easel/print
import eyg/runtime/interpreter as r
import harness/stdlib
import harness/effect

// Not a full app
// Widget is another name element/panel
// Embed if I have a separate app file

pub type Mode {
  Command(warning: String)
  Insert
}

pub type Embed {
  Embed(
    mode: Mode,
    source: e.Expression,
    rendered: #(List(print.Rendered), map.Map(String, Int)),
  )
}

pub fn source() {
  e.Let(
    "message",
    e.Binary("Hello, World!"),
    e.Let(
      "greet",
      e.Lambda("message", e.Apply(e.Perform("Alert"), e.Variable("message"))),
      e.Apply(e.Variable("greet"), e.Variable("message")),
    ),
  )
}

pub fn init() {
  let s = source()
  let rendered = print.print(s)
  Embed(Command(""), s, rendered)
}

pub fn child(expression, index) {
  case expression, index {
    e.Lambda(param, body), 0 -> Ok(#(body, e.Lambda(param, _)))
    e.Apply(func, arg), 0 -> Ok(#(func, e.Apply(_, arg)))
    e.Apply(func, arg), 1 -> Ok(#(arg, e.Apply(func, _)))
    e.Let(label, value, then), 0 -> Ok(#(value, e.Let(label, _, then)))
    e.Let(label, value, then), 1 -> Ok(#(then, e.Let(label, value, _)))
    _, _ -> Error(Nil)
  }
  // This is one of the things that would be harder with overwrite having children
}

pub fn zipper(expression, path) {
  do_zipper(expression, path, [])
}

fn do_zipper(expression, path, acc) {
  case path {
    [] ->
      Ok(#(
        expression,
        fn(new) { list.fold(acc, new, fn(element, build) { build(element) }) },
      ))
    [index, ..path] -> {
      use #(child, rebuild) <- result.then(child(expression, index))
      do_zipper(child, path, [rebuild, ..acc])
    }
  }
}

pub fn insert_text(state: Embed, data, start, end) {
  let rendered = state.rendered.0
  case state.mode {
    Command(_) -> {
      case data {
        " " -> {
          let message = run(state)
          let state = Embed(..state, mode: Command(message))
          #(state, start)
        }
        "w" -> call_with(state, start, end)
        "i" -> #(Embed(..state, mode: Insert), start)
        "[" -> list_element(state, start, end)
        "d" -> delete(state, start, end)
        "f" -> insert_function(state, start, end)
        "g" -> select(state, start, end)
        "c" -> call(state, start, end)

        // TODO reuse history and inference components
        // Reuse lookup of variables
        // Don't worry about big code blocks at this point, I can use my silly backwards editor
        // hardcode stdlib at the top
        // run needs to be added
        // embed can have a minimum height then safe to show logs when running
        // terminal at the bottom can have a line buffer for reading input
        key -> {
          let mode = Command(string.append("no command for key ", key))
          #(Embed(..state, mode: mode), start)
        }
      }
    }
    Insert -> {
      let assert Ok(#(_ch, path, cut_start, _style)) = list.at(rendered, start)
      let assert Ok(#(_ch, _, cut_end, _style)) = list.at(rendered, end)
      let #(path, cut_start) = case cut_start < 0 {
        True -> {
          let assert Ok(#(_ch, path, cut_start, _style)) =
            list.at(rendered, start - 1)
          #(path, cut_start + 1)
        }
        False -> #(path, cut_start)
      }
      // /Only move left if letter, not say comma, but is it weird to have commands available in insert mode
      // probably but let's try and push as many things to insert mode do command mode not needed
      // I would do this if CTRL functions not so overloaded
      // key press on vacant same in insert and cmd mode
      let #(p2, cut_end) = case cut_end < 0 {
        True -> {
          let assert Ok(#(_ch, path, cut_end, _style)) =
            list.at(rendered, end - 1)
          #(path, cut_end + 1)
        }
        False -> #(path, cut_end)
      }
      case path != p2 || cut_start < 0 {
        True -> {
          #(state, start)
        }
        _ -> {
          let assert Ok(#(target, rezip)) = zipper(state.source, path)
          // always the same path
          let #(new, sub, offset) = case target {
            e.Lambda(param, body) -> {
              let #(param, offset) = replace_at(param, cut_start, cut_end, data)
              #(e.Lambda(param, body), [], offset)
            }
            e.Apply(e.Apply(e.Cons, _), _) -> {
              let new = e.Apply(e.Apply(e.Cons, e.Vacant("")), target)
              #(new, [0, 1], 0)
            }
            e.Let(label, value, then) -> {
              let #(label, offset) = replace_at(label, cut_start, cut_end, data)
              #(e.Let(label, value, then), [], offset)
            }
            e.Variable(label) -> {
              let #(label, offset) = replace_at(label, cut_start, cut_end, data)
              let new = case label {
                "" -> e.Vacant("")
                _ -> e.Variable(label)
              }
              #(new, [], offset)
            }
            e.Vacant(_) ->
              case data {
                "\"" -> #(e.Binary(""), [], 0)
                "[" -> #(e.Tail, [], 0)
                "{" -> #(e.Empty, [], 0)
                // TODO need to add path to step in
                "(" -> #(e.Apply(e.Vacant(""), e.Vacant("")), [], 0)
                "=" -> #(e.Let("", e.Vacant(""), e.Vacant("")), [], 0)
                "|" -> #(
                  e.Apply(e.Apply(e.Case(""), e.Vacant("")), e.Vacant("")),
                  [],
                  0,
                )
                "^" -> #(e.Perform(""), [], 0)
                _ -> {
                  let assert Ok(re) = regex.from_string("^[a-zA-Z]$")
                  case int.parse(data) {
                    Ok(number) -> #(e.Integer(number), [], string.length(data))
                    Error(Nil) ->
                      case regex.check(re, data) {
                        True -> #(e.Variable(data), [], string.length(data))
                        _ -> #(target, [], cut_start)
                      }
                  }
                }
              }
            e.Binary(value) -> {
              let value = stringx.replace_at(value, cut_start, cut_end, data)
              #(e.Binary(value), [], cut_start + string.length(data))
            }
            e.Integer(value) -> {
              case data == "-" && cut_start == 0 {
                True -> #(e.Integer(0 - value), [], 1)
                False ->
                  case int.parse(data) {
                    Ok(_) -> {
                      let assert Ok(value) =
                        int.to_string(value)
                        |> stringx.replace_at(cut_start, cut_end, data)
                        |> int.parse()
                      #(e.Integer(value), [], cut_start + string.length(data))
                    }
                    Error(Nil) -> #(target, [], cut_start)
                  }
              }
            }
            e.Tail -> {
              case data {
                "," -> #(
                  e.Apply(e.Apply(e.Cons, e.Vacant("")), e.Vacant("")),
                  [0, 1],
                  cut_start,
                )
              }
            }
            e.Extend(label) -> {
              let #(label, offset) = replace_at(label, cut_start, cut_end, data)
              #(e.Extend(label), [], offset)
            }
            e.Select(label) -> {
              let #(label, offset) = replace_at(label, cut_start, cut_end, data)
              #(e.Select(label), [], offset)
            }
            e.Overwrite(label) -> {
              let #(label, offset) = replace_at(label, cut_start, cut_end, data)
              #(e.Overwrite(label), [], offset)
            }

            e.Perform(label) -> {
              let #(label, offset) = replace_at(label, cut_start, cut_end, data)
              #(e.Perform(label), [], offset)
            }
            e.Handle(label) -> {
              let #(label, offset) = replace_at(label, cut_start, cut_end, data)
              #(e.Handle(label), [], offset)
            }
            node -> {
              io.debug(#("nothing", node))
              #(node, [], cut_start)
            }
          }
          let source = rezip(new)
          // TODO move to update source
          let rendered = print.print(source)
          // zip and target
          // io.debug(rendered)

          // update source source have a offset function
          let path = list.append(path, sub)
          let assert Ok(start) = map.get(rendered.1, print.path_to_string(path))
          #(Embed(..state, source: source, rendered: rendered), start + offset)
        }
      }
    }
  }
}

fn replace_at(label, start, end, data) {
  let start = int.min(string.length(label), start)
  let label = stringx.replace_at(label, start, end, data)
  #(label, start + string.length(data))
}

fn run(state: Embed) {
  let #(_lift, _resume, handler) = effect.window_alert()

  let handlers =
    map.new()
    |> map.insert("Alert", handler)
  let env = stdlib.env()
  case r.handle(r.eval(state.source, env, r.Value), env.builtins, handlers) {
    r.Abort(reason) -> reason_to_string(reason)
    r.Value(term) -> term_to_string(term)
    _ -> panic("this should be tackled better in the run code")
  }
}

fn reason_to_string(reason) {
  case reason {
    r.UndefinedVariable(var) -> string.append("variable undefined: ", var)
    r.IncorrectTerm(expected, _got) ->
      string.concat(["unexpected term, expected", expected])
    r.MissingField(field) -> string.concat(["missing record field", field])
    r.NoCases -> string.concat(["no cases matched"])
    r.NotAFunction(term) -> "not a function"
    r.UnhandledEffect(effect, _with) ->
      string.concat(["unhandled effect ", effect])
    r.Vacant(note) -> "tried to run a todo"
  }
}

fn term_to_string(term) {
  case term {
    r.Binary(value) -> string.concat(["\"", value, "\""])
    _ -> "non string term"
  }
}

pub fn list_element(state: Embed, start, end) {
  let assert Ok(#(_ch, path, cut_start, _style)) =
    list.at(state.rendered.0, start)
  let assert Ok(#(_ch, p2, cut_end, _style)) = list.at(state.rendered.0, end)
  case path != p2 {
    True -> {
      #(state, start)
    }
    False -> {
      let assert Ok(#(target, rezip)) = zipper(state.source, path)
      let source = rezip(e.Apply(e.Apply(e.Cons, target), e.Tail))
      // TODO move to update source
      let rendered = print.print(source)
      let assert Ok(start) = map.get(rendered.1, print.path_to_string(path))
      #(Embed(mode: Insert, source: source, rendered: rendered), start)
    }
  }
}

pub fn delete(state: Embed, start, end) {
  let assert Ok(#(_ch, path, cut_start, _style)) =
    list.at(state.rendered.0, start)
  let assert Ok(#(_ch, p2, cut_end, _style)) = list.at(state.rendered.0, end)
  case path != p2 {
    True -> {
      #(state, start)
    }
    False -> {
      let assert Ok(#(target, rezip)) = zipper(state.source, path)
      let source = rezip(e.Vacant(""))
      // TODO move to update source
      let rendered = print.print(source)
      let assert Ok(start) = map.get(rendered.1, print.path_to_string(path))
      #(Embed(mode: Insert, source: source, rendered: rendered), start)
    }
  }
}

pub fn insert_function(state: Embed, start, end) {
  let assert Ok(#(_ch, path, cut_start, _style)) =
    list.at(state.rendered.0, start)
  let assert Ok(#(_ch, p2, cut_end, _style)) = list.at(state.rendered.0, end)
  case path != p2 {
    True -> {
      #(state, start)
    }
    False -> {
      let assert Ok(#(target, rezip)) = zipper(state.source, path)
      let source = rezip(e.Lambda("", target))
      // TODO move to update source
      let rendered = print.print(source)
      let assert Ok(start) = map.get(rendered.1, print.path_to_string(path))
      #(Embed(mode: Insert, source: source, rendered: rendered), start)
    }
  }
}

pub fn select(state: Embed, start, end) {
  let assert Ok(#(_ch, path, cut_start, _style)) =
    list.at(state.rendered.0, start)
  let assert Ok(#(_ch, p2, cut_end, _style)) = list.at(state.rendered.0, end)
  case path != p2 {
    True -> {
      #(state, start)
    }
    False -> {
      let assert Ok(#(target, rezip)) = zipper(state.source, path)
      let source = rezip(e.Apply(e.Select(""), target))
      // TODO move to update source
      let rendered = print.print(source)
      let assert Ok(start) = map.get(rendered.1, print.path_to_string(path))
      #(Embed(mode: Insert, source: source, rendered: rendered), start)
    }
  }
}

pub fn call_with(state: Embed, start, end) {
  let assert Ok(#(_ch, path, cut_start, _style)) =
    list.at(state.rendered.0, start)
  let assert Ok(#(_ch, p2, cut_end, _style)) = list.at(state.rendered.0, end)
  case path != p2 {
    True -> {
      #(state, start)
    }
    False -> {
      let assert Ok(#(target, rezip)) = zipper(state.source, path)
      let source = rezip(e.Apply(e.Vacant(""), target))
      // TODO move to update source
      let rendered = print.print(source)
      let assert Ok(start) =
        map.get(rendered.1, print.path_to_string(list.append(path, [0])))
      #(Embed(..state, source: source, rendered: rendered), start)
    }
  }
}

pub fn call(state: Embed, start, end) {
  let assert Ok(#(_ch, path, cut_start, _style)) =
    list.at(state.rendered.0, start)
  let assert Ok(#(_ch, p2, cut_end, _style)) = list.at(state.rendered.0, end)
  case path != p2 {
    True -> {
      #(state, start)
    }
    False -> {
      let assert Ok(#(target, rezip)) = zipper(state.source, path)
      let source = rezip(e.Apply(target, e.Vacant("")))
      // TODO move to update source
      let rendered = print.print(source)
      let assert Ok(start) =
        map.get(rendered.1, print.path_to_string(list.append(path, [1])))
      #(Embed(..state, source: source, rendered: rendered), start)
    }
  }
}

pub fn insert_paragraph(index, state: Embed) {
  let assert Ok(#(_ch, path, offset, _style)) = list.at(state.rendered.0, index)
  let assert Ok(#(target, rezip)) = zipper(state.source, path)

  let new = case target {
    e.Let(label, value, then) -> {
      e.Let(label, value, e.Let("", e.Vacant(""), then))
    }
    node -> e.Let("", node, e.Vacant(""))
  }
  let source = rezip(new)
  let rendered = print.print(source)
  let assert Ok(start) =
    map.get(rendered.1, print.path_to_string(list.append(path, [1])))
  #(Embed(mode: Insert, source: source, rendered: rendered), start)
}

pub fn html(embed: Embed) {
  embed.rendered.0
  |> group
  |> to_html()
}

pub fn pallet(embed: Embed) {
  case embed.mode {
    Command(warning) -> {
      let message = case warning {
        "" -> "press space to run"
        message -> message
      }
      string.append(":", message)
    }
    Insert -> "insert"
  }
}

fn to_html(sections) {
  list.fold(
    sections,
    "",
    fn(acc, section) {
      let #(style, letters) = section
      let class = case style {
        print.Default -> ""
        print.Keyword -> "text-gray-500"
        print.Missing -> "text-pink-3"
        print.Hole -> "text-orange-4 font-bold"
        print.Integer -> "text-purple-4"
        print.String -> "text-green-4"
        print.Union -> "text-blue-3"
        print.Effect -> "text-yellow-4"
        print.Builtin -> "font-italic"
      }
      string.concat([
        acc,
        "<span class=\"",
        class,
        "\">",
        string.concat(letters),
        "</span>",
      ])
    },
  )
}

fn group(rendered: List(print.Rendered)) {
  // list.fold(rendered, #([[first.0]], first.2), fn(state) {
  //   let #(store,)
  //  })
  case rendered {
    [] -> []
    [#(ch, _path, offset, style), ..rendered] ->
      do_group(rendered, [ch], [], style)
  }
}

fn do_group(rest, current, acc, style) {
  case rest {
    [] -> list.reverse([#(style, list.reverse(current)), ..acc])
    [#(ch, _path, _offset, s), ..rest] ->
      case s == style {
        True -> do_group(rest, [ch, ..current], acc, style)
        False ->
          do_group(rest, [ch], [#(style, list.reverse(current)), ..acc], s)
      }
  }
}

pub fn blur(state) {
  escape(state)
}

pub fn escape(state) {
  Embed(..state, mode: Command(""))
}
