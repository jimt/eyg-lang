import eyg/analysis/type_/binding/debug
import eyg/parse
import eyg/parse/lexer
import eyg/parse/parser
import eyg/runtime/value as v
import eyg/text/highlight
import eyg/text/text
import eygir/annotated
import gleam/dict
import gleam/dynamic
import gleam/http/request
import gleam/int
import gleam/io
import gleam/list
import gleam/listx
import gleam/option.{None, Some}
import gleam/pair
import gleam/string
import gleam/uri
import intro/snippet
import intro/state
import lustre/attribute as a
import lustre/element.{fragment, none, text} as _
import lustre/element/html as h
import lustre/event as e
import plinth/browser/document
import plinth/browser/element
import plinth/browser/event
import plinth/browser/window

const peach_background = "<svg class=\"w-full h-screen\" id=\"visual\" viewBox=\"0 0 900 600\" xmlns=\"http://www.w3.org/2000/svg\"
    xmlns:xlink=\"http://www.w3.org/1999/xlink\" version=\"1.1\">
    <defs>
      <filter id=\"blur1\" x=\"-10%\" y=\"-10%\" width=\"120%\" height=\"120%\">
        <feFlood flood-opacity=\"0\" result=\"BackgroundImageFix\"></feFlood>
        <feBlend mode=\"normal\" in=\"SourceGraphic\" in2=\"BackgroundImageFix\" result=\"shape\"></feBlend>
        <feGaussianBlur stdDeviation=\"150\" result=\"effect1_foregroundBlur\"></feGaussianBlur>
      </filter>
    </defs>
    <g filter=\"url(#blur1)\">
      <circle cx=\"852\" cy=\"489\" fill=\"#ffc0cb\" r=\"357\"></circle>
      <circle cx=\"1000\" cy=\"36\" fill=\"#ffc0cb\" r=\"200\"></circle>
      <circle cx=\"290\" cy=\"750\" fill=\"#ffa07a\" r=\"357\"></circle>
      <circle cx=\"100\" cy=\"10\" fill=\"#ffc0cb\" r=\"100\"></circle>    
      <circle cx=\"280\" cy=\"-50\" fill=\"#ffa07a\" r=\"100\"></circle>    

    </g>
  </svg>"

const background = "<svg class=\"w-full h-screen\" id=\"visual\" viewBox=\"0 0 900 600\" xmlns=\"http://www.w3.org/2000/svg\"
    xmlns:xlink=\"http://www.w3.org/1999/xlink\" version=\"1.1\">
    <defs>
      <filter id=\"blur1\" x=\"-10%\" y=\"-10%\" width=\"120%\" height=\"120%\">
        <feFlood flood-opacity=\"0\" result=\"BackgroundImageFix\"></feFlood>
        <feBlend mode=\"normal\" in=\"SourceGraphic\" in2=\"BackgroundImageFix\" result=\"shape\"></feBlend>
        <feGaussianBlur stdDeviation=\"20\" result=\"effect1_foregroundBlur\"></feGaussianBlur>
      </filter>
    </defs>
    <g filter=\"url(#blur1)\">
      <circle cx=\"100\" cy=\"-70\" fill=\"#f4d738\" r=\"100\"></circle>    
      <circle cx=\"150\" cy=\"-20\" fill=\"#90ee90\" r=\"40\"></circle>    

      <circle cx=\"910\" cy=\"36\" fill=\"#f4d738\" r=\"40\"></circle>
      <circle cx=\"1000\" cy=\"170\" fill=\"#90ee90\" r=\"140\"></circle>

      <circle cx=\"360\" cy=\"680\" fill=\"#f4d738\" r=\"170\"></circle>
      <circle cx=\"280\" cy=\"620\" fill=\"#f4d738\" r=\"50\"></circle>    

    </g>
  </svg>"

pub fn render(state) {
  // container has svg element
  h.div(
    [
      a.class("relative min-h-screen"),
      a.style([
        // #("background-color", "#ffffeb")
      ]),
    ],
    [
      h.div(
        [
          a.class("fixed top-0 bottom-0 left-0 right-0"),
          a.attribute("dangerous-unescaped-html", background),
        ],
        [],
      ),
      content(state),
      runner(state),
    ],
  )
}

pub fn runner(state) {
  let state.State(sections: sections, running: runner, ..) = state
  case runner {
    None -> none()
    Some(state.Runner(handle, effects)) ->
      h.div(
        [
          a.class(
            "bg-white bottom-8 fixed right-4 rounded top-4 w-1/3 shadow-xl border",
          ),
          a.style([#("left", "96ch")]),
        ],
        [
          h.h1([a.class("text-right")], [
            // text("Running ..."),
            h.button([e.on_click(state.CloseRunner)], [text("close")]),
          ]),
          logs1(list.reverse(effects)),
          case handle {
            state.Abort(message) ->
              h.div([a.class("bg-red-300 p-10")], [text(message)])
            state.Suspended(state.TextInput(question, value), env, k) ->
              h.div([a.class("border-4 border-green-500 px-6 py-2")], [
                h.div([], [text(question)]),
                h.form(
                  [e.on_submit(state.Unsuspend(state.Asked(question, value)))],
                  [
                    h.input([
                      a.class("border rounded"),
                      a.value(value),
                      e.on_input(fn(value) {
                        state.UpdateSuspend(state.TextInput(question, value))
                      }),
                    ]),
                  ],
                ),
              ])
            state.Suspended(state.Loading(reference), _, _) ->
              h.div([a.class("border-4 border-gray-500 px-6 py-2")], [
                h.div([], [text("Loading: #" <> reference)]),
              ])
            state.Suspended(state.Awaiting, _, _) ->
              h.div([a.class("border-4 border-gray-500 px-6 py-2")], [
                h.div([], [text("Awaiting: ")]),
              ])
            state.Suspended(state.Fetch(request), _, _) ->
              h.div([a.class("border-4 border-gray-500 px-6 py-2")], [
                h.div([], [
                  text("Fetching: #" <> uri.to_string(request.to_uri(request))),
                ]),
              ])
            state.Suspended(state.Timer(remaining), _, _) ->
              h.div([a.class("border-4 border-blue-500 px-6 py-2")], [
                h.div([], [text("Waiting " <> int.to_string(remaining))]),
              ])
            state.Suspended(state.Geo, _, _) ->
              h.div([a.class("border-4 border-blue-500 px-6 py-2")], [
                h.div([], [text("Finding location ")]),
              ])
            state.Done(value) ->
              h.div([a.class("border-4 border-green-500 px-6 py-2")], [
                h.div([], [text("Done")]),
                h.div([], [text(v.debug(value))]),
              ])
            // _ -> text()
          },
        ],
      )
  }
}

fn logs1(logs) {
  h.div(
    [
      a.style([
        #("display", "grid"),
        #("grid-template-columns", "minmax(8ch, auto) 1fr"),
      ]),
    ],
    list.flat_map(logs, fn(effect) {
      case effect {
        state.Log(message) -> [
          h.span([a.class("bg-gray-700 text-white text-right px-2")], [
            text("Log"),
          ]),
          h.span([a.class("px-1")], [text(message)]),
        ]
        state.Waited(time) -> [
          h.span([a.class("bg-blue-700 text-white text-right px-2")], [
            text("Wait"),
          ]),
          h.span([a.class("px-1")], [text(int.to_string(time))]),
        ]
        state.Awaited(_value) -> [
          h.span([a.class("bg-gray-700 text-white text-right px-2")], [
            text("Awaited"),
          ]),
          h.span([a.class("px-1")], []),
        ]
        state.Geolocation(_) -> [
          h.span([a.class("bg-blue-700 text-white text-right px-2")], [
            text("Geo"),
          ]),
          h.span([a.class("px-1")], []),
        ]
        state.Asked(question, answer) -> [
          h.span([a.class("bg-gray-700 text-white text-right px-2")], [
            text("Ask"),
          ]),
          h.span([a.class("px-1")], [text(question), text(": "), text(answer)]),
        ]
        state.Fetched(request) -> [
          h.span([a.class("bg-gray-700 text-white text-right px-2")], [
            text("Fetched"),
          ]),
          h.span([a.class("px-1")], [
            text(uri.to_string(request.to_uri(request))),
          ]),
        ]
      }
    }),
  )
}

pub fn content(state) {
  let state.State(sections: sections, ..) = state
  h.div([a.class("relative vstack")], [
    h.div([a.class("cover expand")], [
      h.h1([a.class("p-4 text-6xl")], [text("Eyg")]),
      // fixed doesnt respect the colum 
      // whole extra grid doesn't work
      // h.div([a.class("")], [
      //   h.div(
      //     [
      //       a.class("mx-auto fixed top-0 left-0 right-0 bottom-0"),
      //       a.style([
      //         #("display", "grid"),
      //         #("grid-template-columns", "8em 80ch 1fr"),
      //       ]),
      //     ],
      //     [
      //       h.div([], [text("1")]),
      //       h.div([], [text("2")]),
      //       h.div([], [h.div([a.class("h-full bg-red-200")], [runner(state)])]),
      //     ],
      //   ),
      // ]),
      h.div([a.class("")], list.index_map(sections, section)),
    ]),
    // bad things with min h 100% in relative maybe fixed is better than sticky
    // sticky works as long as there is content
    h.footer([a.class("cover sticky bottom-0 mt-64 bg-gray-900 text-white")], [
      text("hi"),
    ]),
  ])
}

fn section(section, index) {
  let #(context, code, snippet) = section

  let on_update = fn(new) { state.EditCode(index, new) }

  let errors = case snippet {
    Ok(snippet.Snippet(errors: errors, ..)) ->
      errors
      |> list.map(fn(error) { #(debug.render_reason(error.0), error.1) })
    Error(reason) -> {
      let end = string.byte_size(code)
      let #(message, start) = case reason {
        parser.UnexpectedToken(position: position, token: token) -> {
          #("Unexpected code token: " <> string.inspect(token), position)
        }
        parser.UnexpectEnd -> #("Code is unfinished", end)
      }
      [#(message, #(start, end))]
    }
  }
  let #(error_messages, error_spans) = list.unzip(errors)

  // state = previous assignments

  // let #(can_run, errors, state) = case parse.block_from_string(code) {
  //   Ok(#(#(assigns, final), _remaining_tokens)) -> {
  //     let errors = state.type_errors(assigns, final, references)

  //     let assigns = list.append(assigns, state)
  //     let #(exp, target) = case final, assigns {
  //       None, [#(label, _, span), ..] -> #(
  //         #(annotated.Variable(label), #(0, 0)),
  //         Some(span),
  //       )
  //       None, [] -> #(#(annotated.Empty, #(0, 0)), None)
  //       Some(other), _ -> #(other, None)
  //     }
  //     let target =
  //       option.map(target, fn(span) {
  //         let #(start, _) = span
  //         text.offset_line_number(code, start)
  //       })
  //     let exp = state.rollup_block(exp, assigns)
  //     #(Ok(#(exp, target)), errors, assigns)
  //   }
  //   Error(reason) -> {
  //     #(Error(reason), [], state)
  //   }
  // }

  h.div([a.class("")], [
    h.div(
      [
        a.class("mx-auto"),
        a.style([
          #("display", "grid"),
          #("grid-template-columns", "8em 100ch 1fr"),
        ]),
      ],
      [
        h.div([a.style([#("align-self", "bottom")])], [
          // text("effects")
        ]),
        h.div([a.class("my-4 bg-white bg-opacity-70 rounded")], [context]),
        h.div([], []),
        h.div(
          [a.class("my-4 p-2 text-right")],
          [],
          // case can_run {
        //   Ok(#(exp, Some(count))) ->
        //     list.repeat(h.br([]), count)
        //     |> list.append([
        //       h.button(
        //         [
        //           a.class("bg-red-400 text-white px-2 -mr-2 rounded-l"),
        //           e.on_click(state.Run(exp)),
        //         ],
        //         [text("Run >")],
        //       ),
        //     ])
        //   _ -> []
        // }
        ),
        h.div([a.class("my-4 bg-gray-200 rounded bg-opacity-70")], [
          h.div([a.class("p-2")], [text_input(code, on_update, [])]),
          h.div(
            [a.class("")],
            list.map(error_messages, fn(message) {
              h.div(
                [a.class("px-2 -mt-1 py-1 rounded bg-pink-500 text-white")],
                [text(message)],
              )
            }),
          ),
        ]),
        h.div([], []),
      ],
    ),
  ])
}

const monospace = "ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,\"Liberation Mono\",\"Courier New\",monospace"

const pre_id = "highlighting-underlay"

fn text_input(code, on_update, errors) {
  h.div(
    [
      a.style([
        #("position", "relative"),
        #("font-family", monospace),
        #("width", "100%"),
        // #("height", "100%"),

        #("overflow", "hidden"),
      ]),
    ],
    [
      h.pre(
        [
          a.id(pre_id),
          a.style([
            #("position", "absolute"),
            #("top", "0"),
            #("bottom", "0"),
            #("left", "0"),
            #("right", "0"),
            #("margin", "0 !important"),
            #("white-space", "pre-wrap"),
            #("word-wrap", "break-word"),
            #("overflow", "auto"),
          ]),
        ],
        highlighted(code),
      ),
      h.pre(
        [
          a.id(pre_id),
          a.style([
            #("position", "absolute"),
            #("top", "0"),
            #("bottom", "0"),
            #("left", "0"),
            #("right", "0"),
            #("margin", "0 !important"),
            #("white-space", "pre-wrap"),
            #("word-wrap", "break-word"),
            #("overflow", "auto"),
            #("color", "transparent"),
          ]),
        ],
        underline(code, errors),
      ),
      // case parse_error {
      //   Ok(_) -> none()
      //   Error(reason) -> {
      //     let from = case reason {
      //       parser.UnexpectedToken(position: position, ..) -> position
      //       parser.UnexpectEnd -> string.byte_size(code)
      //     }
      //     case pop_bytes(code, from, []) {
      //       Ok(#(pre, post)) -> {
      //         h.pre(
      //           [
      //             a.id(pre_id),
      //             a.style([
      //               #("position", "absolute"),
      //               #("top", "0"),
      //               #("bottom", "0"),
      //               #("left", "0"),
      //               #("right", "0"),
      //               #("margin", "0 !important"),
      //               #("white-space", "pre-wrap"),
      //               #("word-wrap", "break-word"),
      //               #("overflow", "auto"),
      //               #("color", "transparent"),
      //             ]),
      //           ],
      //           [
      //             h.span([], [text(pre)]),
      //             h.span(
      //               [a.style([#("text-decoration", "red wavy underline;")])],
      //               [text(post)],
      //             ),
      //           ],
      //         )
      //       }
      //       Error(_) -> none()
      //     }
      //   }
      // },
      h.textarea(
        [
          a.style([
            #("display", "block"),
            // z-index can cause the highlight to be lot behind other containers. 
            // make this position relative so stacked with absolute elements but do not move.
            #("position", "relative"),
            #("width", "100%"),
            #("height", "100%"),
            #("padding", "0 !important"),
            #("margin", "0 !important"),
            #("border", "0"),
            #("color", "transparent"),
            #("font-size", "1em"),
            #("background-color", "transparent"),
            #("outline", "2px solid transparent"),
            #("outline-offset", "2px"),
            #("caret-color", "black"),
          ]),
          a.attribute("spellcheck", "false"),
          a.rows(text.line_count(code)),
          e.on_input(on_update),
          // stops navigation
          e.on("keydown", fn(event) {
            e.stop_propagation(event)
            Error([])
          }),
          e.on("scroll", fn(event) {
            let target =
              event.target(dynamic.unsafe_coerce(dynamic.from(event)))
            window.request_animation_frame(fn(_) {
              let target = dynamic.unsafe_coerce(target)
              let scroll_top = element.scroll_top(target)
              let scroll_left = element.scroll_left(target)
              let assert Ok(pre) = document.query_selector("#" <> pre_id)
              element.set_scroll_top(pre, scroll_top)
              element.set_scroll_left(pre, scroll_left)
              Nil
            })

            Error([])
          }),
        ],
        code,
      ),
    ],
  )
}

fn highlighted(code) {
  code
  |> lexer.lex()
  |> list.map(pair.first)
  |> highlight.highlight(highlight_token)
}

fn highlight_token(token) {
  let #(classification, content) = token
  let class = case classification {
    highlight.Whitespace -> ""
    highlight.Text -> ""
    highlight.UpperText -> "text-blue-400"
    highlight.Number -> "text-indigo-400"
    highlight.String -> "text-green-500"
    highlight.KeyWord -> "text-gray-700"
    highlight.Effect -> "text-yellow-500"
    highlight.Builtin -> "text-pink-400"
    highlight.Reference -> "text-gray-400"
    highlight.Punctuation -> ""
    highlight.Unknown -> "text-red-500"
  }
  h.span([a.class(class)], [text(content)])
}

fn underline(code, errors) {
  // let code = bit_array.from_string(code)
  let #(_, _, acc) =
    list.fold(errors, #(code, 0, []), fn(state, error) {
      let #(code, offset, acc) = state
      let #(start, end) = error
      let pre = start - offset
      let emp = end - start
      let offset = end
      let assert Ok(#(content, code)) = pop_bytes(code, pre, [])
      let acc = case content {
        "" -> acc
        content -> [h.span([], [text(content)]), ..acc]
      }
      let assert Ok(#(content, code)) = pop_bytes(code, emp, [])
      let acc = case content {
        "" -> acc
        content -> [
          h.span([a.style([#("text-decoration", "red wavy underline;")])], [
            text(content),
          ]),
          ..acc
        ]
      }
      #(code, offset, acc)
      // panic
      // case code {
      //   <<pre:bytes-size(pre), emp:bytes-size(emp), remaining:bytes>> -> {
      //     let assert Ok(pre) = bit_array.to_string(pre)
      //     let acc = case pre {
      //       "" -> acc
      //       content -> [h.span([], [text(content)]), ..acc]
      //     }
      //     let assert Ok(emp) = bit_array.to_string(emp)
      //     let acc = case emp {
      //       "" -> acc
      //       content -> [
      //         h.span([a.style([#("text-decoration", "red wavy underline;")])], [
      //           text(content),
      //         ]),
      //         ..acc
      //       ]
      //     }
      //     #(remaining, offset, acc)
      //   }
      //   _ -> panic
      // }
    })
  list.reverse(acc)
}

fn pop_bytes(string, bytes, acc) {
  case bytes {
    0 -> Ok(#(string.concat(list.reverse(acc)), string))
    x if x > 0 ->
      case string.pop_grapheme(string) {
        Ok(#(g, rest)) -> {
          let bytes = bytes - string.byte_size(g)
          let acc = [g, ..acc]
          pop_bytes(rest, bytes, acc)
        }
        Error(Nil) -> Error(Nil)
      }
    _ -> {
      io.debug("weird bytes")
      Ok(#(string.concat(list.reverse(acc)), string))
    }
  }
}
