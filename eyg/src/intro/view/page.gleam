import eyg/parse/lexer
import eyg/text/highlight
import eyg/text/text
import gleam/dynamic
import gleam/list
import gleam/listx
import gleam/option.{None, Some}
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
  let state.State(sections, runner) = state
  case runner {
    None -> none()
    Some(state.Runner(handle, effects)) ->
      h.div(
        [
          a.class(
            "bg-white bottom-8 fixed right-4 rounded top-4 w-1/3 shadow-xl",
          ),
        ],
        [
          h.h1([], [
            text("Running ..."),
            h.button([e.on_click(state.CloseRunner)], [text("close")]),
          ]),
          logs1(effects),
          case handle {
            state.Abort(message) ->
              h.div([a.class("bg-red-300 p-10")], [text(message)])
            _ -> none()
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
        state.Random(value) -> [
          h.span([a.class("bg-gray-700 text-white text-right px-2")], [
            text("Random"),
          ]),
          h.span([a.class("px-1")], [text("todo")]),
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
      h.div([a.class("")], iterate(sections, section)),
    ]),
    // bad things with min h 100% in relative maybe fixed is better than sticky
    // sticky works as long as there is content
    h.footer([a.class("cover sticky bottom-0 mt-64 bg-gray-900 text-white")], [
      text("hi"),
    ]),
  ])
}

fn do_iterate(remaining, func, previous, acc) {
  case remaining {
    [] -> list.reverse(acc)
    [item, ..remaining] -> {
      let acc = [func(previous, item, remaining), ..acc]
      do_iterate(remaining, func, [item,..previous],acc)
    }
  }
}

fn iterate(items, func) {
  do_iterate(items, func, [], [])
}

fn section(previous, section, post) {
  let #(context, code) = section
  h.div([a.class("")], [
    h.div(
      [
        a.class("mx-auto"),
        a.style([
          #("display", "grid"),
          #("grid-template-columns", "8em 80ch 1fr"),
        ]),
      ],
      [
        h.div([a.style([#("align-self", "bottom")])], [
          // text("effects")
        ]),
        h.div([a.class("my-4 bg-white bg-opacity-70 rounded")], [context]),
        h.div([], []),
        h.div([], []),
        editor(code, fn(new) {
          let #(content, _code) = section
          let section = #(content, new)
          state.EditCode(listx.gather_around(previous, section, post))
        }),
        h.div([], []),
      ],
    ),
  ])
}

fn editor(code, on_update) {
  h.div([a.class("my-4 p-2 bg-gray-200 rounded bg-opacity-70")], [
    text_input(code, on_update),
  ])
}

const monospace = "ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,\"Liberation Mono\",\"Courier New\",monospace"

const pre_id = "highlighting-underlay"

fn text_input(code, on_update) {
  h.div(
    [
      a.style([
        #("position", "relative"),
        #("font-family", monospace),
        #("width", "100%"),
        #("height", "100%"),
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

fn errors(code) {
  information(code <> "\r\nrun")
}

import gleam/pair
import gleam/string

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
    highlight.KeyWord -> "text-gray-600"
    highlight.Effect -> "text-yellow-600"
    highlight.Punctuation -> ""
    highlight.Unknown -> "text-red-500"
  }
  h.span([a.class(class)], [text(content)])
}

import eyg/analysis/inference/levels_j/contextual as j
import eyg/analysis/type_/binding
import eyg/analysis/type_/isomorphic as t
import eyg/parse
import eygir/annotated

pub fn information(source) {
  case parse.from_string(source) {
    Ok(tree) -> {
      let #(tree, spans) = annotated.strip_annotation(tree)
      let #(exp, bindings) = j.infer(tree, t.Empty, 0, j.new_state())
      let acc = annotated.strip_annotation(exp).1
      let acc =
        list.map(acc, fn(node) {
          let #(error, typed, effect, env) = node
          let typed = binding.resolve(typed, bindings)

          let effect = binding.resolve(effect, bindings)
          #(error, typed, effect)
        })

      Ok(#(spans, acc))
    }
    Error(reason) -> Error(reason)
  }
}
