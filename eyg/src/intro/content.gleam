import lustre/attribute as a
import lustre/element.{fragment, none, text} as _
import lustre/element/html as h

const code = "let x = 1
let y = 2
let z = 3
let http = std.http
let set_username = (user_id, name) -> {
  let request = http.get()
  perform Fetch(request)
}
set_username(\"123124248p574975345\", \"Bob\")"

pub fn sections() {
  [
    #(
      h.p([], [text("whats the point")]),
      "let question = \"What's your name?\"
let run = (_) -> {
  let answer = perform Ask(question)
  perform Log(!string_append(\"Hello \", answer))
}",
    ),
    #(
      fragment([
        h.h2([a.class("text-xl")], [text("Handling an effect")]),
        h.div([a.class("")], [
          text(
            "Lorem ipsum, dolor sit amet consectetur adipisicing elit. Totam quae voluptatum animi fuga placeat reprehenderit, quisquam mollitia exercitationem inventore corrupti numquam tempora assumenda eligendi impedit accusamus quidem labore voluptatem saepe?",
          ),
        ]),
      ]),
      "let { string } = #standard_library
let run = (_) -> { 
  let a = match perform Geo({}) {
    Ok({latitude,longitude}) -> { {latitude,longitude} }
   }
  let _ = perform Wait(5000)
  a
}",
    ),
  ]
}
