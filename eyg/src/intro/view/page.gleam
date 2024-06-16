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
  ])
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
    h.h2([a.class("max-w-2xl mx-auto p-4 text-xl")], [
      text("Handling an effect"),
    ]),
    h.div([a.class("max-w-2xl mx-auto px-4")], [
      text(
        "Lorem ipsum, dolor sit amet consectetur adipisicing elit. Totam quae voluptatum animi fuga placeat reprehenderit, quisquam mollitia exercitationem inventore corrupti numquam tempora assumenda eligendi impedit accusamus quidem labore voluptatem saepe?",
      ),
    ]),
    h.div(
      [
        a.class(
          "cover max-w-6xl mx-auto hstack bg-white my-6 border border-white p-4 rounded bg-opacity-80",
        ),
      ],
      [
        h.div([a.class("cover pr-2 border-r mr-2")], [
          h.br([]),
          h.br([]),
          h.br([]),
          h.br([]),
          h.br([]),
          h.br([]),
          h.span([a.class("bg-indigo-500 text-white px-1")], [text("Fetch")]),
          h.br([]),
          h.br([]),
          h.span([a.class("bg-indigo-500 text-white px-1")], [text("Fetch")]),
        ]),
        h.pre([a.class("expand")], [
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
        h.div(
          [a.class("pl-2 border-l border-gray-300 cover italic text-gray-700")],
          [
            h.pre([], [
              text(
                "x = 1
y = 2
z = 3

user_id = 123124248p574975345, name = \"\"Bob
request = {method, scheme, +3 more}


Nil",
              ),
            ]),
          ],
        ),
      ],
    ),
    h.div(
      [
        a.style([
          #("display", "grid"),
          #("grid-template-columns", "25% minmax(50%, 42rem) 25%"),
        ]),
      ],
      [
        h.div([], []),
        h.div([], [
          h.h2(
            [a.class("max-w-2xl mx-auto p-4 text-xl bg-white bg-opacity-60")],
            [text("Handling an effect")],
          ),
          h.div([a.class("max-w-2xl mx-auto p-4 bg-white bg-opacity-60")], [
            text(
              "Lorem ipsum, dolor sit amet consectetur adipisicing elit. Totam quae voluptatum animi fuga placeat reprehenderit, quisquam mollitia exercitationem inventore corrupti numquam tempora assumenda eligendi impedit accusamus quidem labore voluptatem saepe?",
            ),
          ]),
        ]),
        h.div([], []),
        h.div([a.class("cover text-right")], [
          h.br([]),
          h.br([]),
          h.br([]),
          h.br([]),
          h.br([]),
          h.br([]),
          h.span([a.class("bg-indigo-500 text-white px-1")], [text("Fetch")]),
          h.br([]),
          h.br([]),
          h.span([a.class("bg-indigo-500 text-white px-1")], [text("Fetch")]),
        ]),
        h.pre([a.class("expand px-4 bg-white bg-opacity-60")], [
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
        h.div([a.class("pl-2 cover italic")], [
          h.pre([], [
            text(
              "x = 1
y = 2
z = 3

user_id = 123124248p574975345, name = \"\"Bob
request = {method, scheme, +3 more}


Nil",
            ),
          ]),
        ]),
      ],
    ),
  ])
}
