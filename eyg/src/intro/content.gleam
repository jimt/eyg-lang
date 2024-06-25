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
      "let { string } = #standard_library

let run = (_) -> {
  let answer = perform Ask(\"What's your name?\")
  perform Log(string.append(\"Hello \", answer))
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
    // TODO highlight error when tokenising
    // TODO numbers
    // need next item stack
    #(
      h.div([], [text("json")]),
      "let { list, keylist, string } = #standard_library

let digits = [\"1\", \"2\", \"3\", \"4\", \"5\", \"6\", \"7\", \"8\", \"9\", \"0\"]
let whitespace = [\" \", \"\r\n\", \"\n\", \"\t\"]
let literal = [
  {key: \"{\", value: LeftBrace({})},
  {key: \"}\", value: RightBrace({})},
  {key: \"[\", value: LeftBracked({})},
  {key: \"]\", value: RightBracked({})},
  {key: \":\", value: Colon({})},
  {key: \",\", value: Comma({})}
]

let tokenise = !fix((tokenise, acc, buffer) -> {
  let read_string = !fix((read_string, acc, buffer, rest) -> { 
    !pop_prefix(buffer, \"\\\\\\\"\", read_string(acc, string.append(buffer,\"\\\"\")), (_) -> {
      !pop_prefix(buffer, \"\\\"\", read_string(acc, tokenise([String(buffer) ,..acc]), (_) -> {
        match pop_grapheme(rest) {
          Ok({head, tail}) -> { read_string(acc, string.append(buffer, head), tail) }
          Error(_) -> { todo }
        }
      })
    })
  })

  !pop_prefix(buffer, \"true\", tokenise([True({}), ..acc]), (_) -> { 
    !pop_prefix(buffer, \"false\", tokenise([False({}), ..acc]), (_) -> { 
      !pop_prefix(buffer, \"null\", tokenise([Null({}), ..acc]), (_) -> { 
        !pop_prefix(buffer, \"\\\"\", read_string(acc, \"\"), (_) -> { 
          match !pop_grapheme(buffer) {
            Ok({head, tail}) -> { 
              match list.contains(whitespace, head) {
                True(_) -> { tokenise(acc, tail, buffer) }
                False(_) -> { 
                  match keylist.find(literal, head) {
                    Ok(token) -> { tokenise([token, ..acc], tail) }
                    Error(_) -> { todo }
                  }
                }
              }
            }
            Error(_) -> { list.reverse(acc) }
          }
        })
      })
    })
  })
})
let run = (_) -> {
  tokenise([],\"\\\"true\\\" : false\")
} ",
    ),
  ]
}
