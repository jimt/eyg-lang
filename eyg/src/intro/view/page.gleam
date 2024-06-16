import gleam/list
import lustre/attribute as a
import lustre/element.{text}
import lustre/element/html as h

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

// TODO use main for code
// TODO em vs char
pub fn render(state) {
  // container has svg element
  h.div([a.class("relative"), a.style([#("background-color", "#ffffeb")])], [
    h.div(
      [
        a.class("fixed top-0 bottom-0 left-0 right-0"),
        a.attribute("dangerous-unescaped-html", background),
      ],
      [],
    ),
    content(state),
    runner(state),
  ])
}

pub fn runner(state) {
  h.div(
    [
      a.class(
        "bg-white bg-opacity-70 bottom-8 fixed p-2 right-4 rounded top-4 w-1/3",
      ),
    ],
    [
      h.h1([], [text("Running ...")]),
      // h.div([], [text("Log "), text("Hello World!")]),
      // h.div([], [text("Ask")]),
      h.br([]),
      h.div([a.class("my-1 rounded px-2 bg-green-300")], [
        h.span(
          [a.class("font-bold text-right text-gray-600 inline-block w-20 mr-1")],
          [text("Log ")],
        ),
        text("Hello, World!"),
      ]),
      h.div([a.class("my-1 rounded px-2 bg-pink-300")], [
        h.span(
          [a.class("font-bold text-right text-gray-600 inline-block w-20 mr-1")],
          [text("Random ")],
        ),
        text("5"),
        h.button([a.class("ml-30 italic")], [text("click to change")]),
      ]),
      h.div([a.class("my-1 rounded px-2 bg-green-300")], [
        h.span(
          [a.class("font-bold text-right text-gray-600 inline-block w-20 mr-1")],
          [text("Log ")],
        ),
        text("Hello, World!"),
      ]),
      h.div([a.class("my-1 rounded px-2 bg-red-300")], [
        h.span(
          [a.class("font-bold text-right text-gray-600 inline-block w-20 mr-1")],
          [text("Abort ")],
        ),
        text("5"),
      ]),
      h.br([]),
      h.div(
        [a.style([#("display", "grid"), #("grid-template-columns", "8ch 1fr")])],
        [
          h.div([a.class("text-right pr-1 border-r font-bold text-gray-600")], [
            text("Log"),
          ]),
          h.span([a.class("pl-1")], [text("Hello, World!")]),
          h.div([a.class("text-right pr-1 border-r font-bold text-gray-600")], [
            text("Ask"),
          ]),
          h.span([a.class("pl-1")], [
            h.input([a.class("border rounded")]),
            h.button([a.class("inline-block px-2 bg-blue-300")], [
              text("answer"),
            ]),
          ]),
          h.div([a.class("text-right pr-1 border-r font-bold text-gray-600")], [
            text("Log"),
          ]),
          h.span([a.class("pl-1")], [text("Hello, Sam!")]),
        ],
      ),
    ],
  )
}

pub fn content(state) {
  h.div([a.class("relative")], [
    h.div([a.class("cover expand")], [
      h.h1([a.class("p-4 text-6xl")], [text("Eyg")]),
      h.div([a.class("")], list.repeat(section(), 10)),
    ]),
    h.footer([a.class("cover sticky bottom-0 bg-gray-900 text-white")], [
      text("hi"),
    ]),
  ])
}

fn section() {
  h.div([a.class("")], [
    //     h.h2([a.class("max-w-2xl mx-auto p-4 text-xl")], [
    //       text("Handling an effect"),
    //     ]),
    //     h.div([a.class("max-w-2xl mx-auto px-4")], [
    //       text(
    //         "Lorem ipsum, dolor sit amet consectetur adipisicing elit. Totam quae voluptatum animi fuga placeat reprehenderit, quisquam mollitia exercitationem inventore corrupti numquam tempora assumenda eligendi impedit accusamus quidem labore voluptatem saepe?",
    //       ),
    //     ]),
    //     h.div(
    //       [
    //         a.class(
    //           "cover max-w-6xl mx-auto hstack bg-white my-6 border border-white p-4 rounded bg-opacity-70",
    //         ),
    //       ],
    //       [
    //         h.div([a.class("cover pr-2 border-r mr-2")], [
    //           h.br([]),
    //           h.br([]),
    //           h.br([]),
    //           h.br([]),
    //           h.br([]),
    //           h.br([]),
    //           h.span([a.class("bg-indigo-500 text-white px-1")], [text("Fetch")]),
    //           h.br([]),
    //           h.br([]),
    //           h.span([a.class("bg-indigo-500 text-white px-1")], [text("Fetch")]),
    //         ]),
    //         h.pre([a.class("expand")], [
    //           text(
    //             "let x = 1
    // let y = 2
    // let z = 3
    // let http = std.http
    // let set_username = (user_id, name) -> {
    //   let request = http.get()
    //   perform Fetch(request)
    // }
    // set_username(\"123124248p574975345\", \"Bob\")",
    //           ),
    //         ]),
    //         h.div(
    //           [a.class("pl-2 border-l border-gray-300 cover italic text-gray-700")],
    //           [
    //             h.pre([], [
    //               text(
    //                 "x = 1
    // y = 2
    // z = 3

    // user_id = 123124248p574975345, name = \"\"Bob
    // request = {method, scheme, +3 more}

    // Nil",
    //               ),
    //             ]),
    //           ],
    //         ),
    //       ],
    //     ),
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
        h.div([a.class("bg-white bg-opacity-70")], [
          h.h2([a.class("p-2 text-xl")], [text("Handling an effect")]),
          h.div([a.class("p-2")], [
            text(
              "Lorem ipsum, dolor sit amet consectetur adipisicing elit. Totam quae voluptatum animi fuga placeat reprehenderit, quisquam mollitia exercitationem inventore corrupti numquam tempora assumenda eligendi impedit accusamus quidem labore voluptatem saepe?",
            ),
          ]),
        ]),
        h.div([], []),
        h.div([a.class("cover text-right py-2")], [
          // h.br([]),
        // h.br([]),
        // h.br([]),
        // h.br([]),
        // h.br([]),
        // h.br([]),
        // h.span(
        //   [
        //     a.class("block text-white px-1"),
        //     a.style([
        //       #("margin-right", "-80ch"),
        //       #("padding-right", "82ch"),
        //       #("background-color", "#69d2e7"),
        //     ]),
        //   ],
        //   [text("Fetch")],
        // ),
        // h.br([]),
        // // one less br when a block
        // // h.br([]),
        // h.span(
        //   [
        //     a.class("block text-white px-1"),
        //     a.style([
        //       #("margin-right", "-80ch"),
        //       #("padding-right", "82ch"),
        //       #("background-color", "#69d2e7"),
        //     ]),
        //   ],
        //   [text("Fetch")],
        // ),
        ]),
        h.pre([a.class("expand p-2 bg-white bg-opacity-70")], [
          text(
            "let x = 1
let y = 2
let z = 3
let http = std.http
let set_username = (user_id, name) -> {
  let request = http.get()
  perform Fetch(request)
}
set_username(\"123124248p574975345\", \"Bob\")",
          ),
        ]),
        h.div([a.class("ml-2 cover italic py-2")], [
          //           h.pre([], [
        //             text(
        //               "x = 1
        // y = 2
        // z = 3

        // user_id = 123124248p574975345, name = \"\"Bob
        // request = {method, scheme, +3 more}

        // Nil",
        //             ),
        //           ]),
        ]),
      ],
    ),
  ])
}
