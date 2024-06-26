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

let read_string = !fix((read_string, gathered, rest) -> { 
  !pop_prefix(rest, \"\\\\\\\"\", 
    read_string(string.append(gathered, \"\\\"\")), (_) -> {
    !pop_prefix(rest, \"\\\"\", 
      (rest) -> { Ok({gathered, rest}) }, 
      (_) -> {
        match string.pop_grapheme(rest) {
          Ok({head, tail}) -> { read_string(string.append(gathered, head), tail) }
          Error(_) -> { Error({}) }
        }
      }
    )
  })
})(\"\")

let tokenise = !fix((tokenise, acc, rest) -> {
  !pop_prefix(rest, \"true\", tokenise([True({}), ..acc]), (_) -> { 
    !pop_prefix(rest, \"false\", tokenise([False({}), ..acc]), (_) -> { 
      !pop_prefix(rest, \"null\", tokenise([Null({}), ..acc]), (_) -> { 
        !pop_prefix(rest, \"\\\"\",
          (rest) -> {
            match read_string(rest) {
              Ok({gathered, rest}) -> { tokenise([String(gathered), ..acc], rest) }
              Error(_) -> { list.reverse([UnterminatedString(rest), ..acc]) }
            }
          }, 
          (_) -> { 
            match !pop_grapheme(rest) {
              Ok({head, tail}) -> { 
                match list.contains(whitespace, head) {
                  True(_) -> { tokenise(acc, tail) }
                  False(_) -> { 
                    match keylist.find(literal, head) {
                      Ok(token) -> { tokenise([token, ..acc], tail) }
                      Error(_) -> { todo_as_read_number }
                    }
                  }
                }
              }
              Error(_) -> { list.reverse(acc) }
            }
          }
        )
      })
    })
  })
})
let run = (_) -> {
  tokenise([],\"\\\"true\\\" : false\")
} ",
    ),
    #(
      h.div([], [text("parseing")]),
      "let string = (k, tokens) -> {
  !uncons(tokens,
    (_) -> { Error(UnexpectedEnd({})) },
    (token, rest) -> { match token {
      String(raw) -> { k(raw, rest) }
      |(_) -> { Error(UnexpectedToken({})) }
    } }
  )
}

let parse = (decoder, raw) -> {
  decoder((out,_rest) -> { out }, tokenise(raw))
}

let run = (_) -> {
  parse(string, \"[]\")
}",
    ),
    #(
      h.div([], [text("HTTP")]),
      "let { http, mime, string } = #standard_library

let expect = (result) -> {
  match result {
    Ok(value) -> { value }
    Error(reason) -> { perform Abort(reason) }
  }
}

let run = (_) -> {
  let request = http.get(\"api.sunrisesunset.io\")
  let request = {
    path: \"/json\",
    query: Some(\"lat=38.907192&lng=-77.036873\"),
    body: !string_to_binary(\"\"),
    ..request}
  let response = expect(perform Await(perform Fetch(request)))
  
  let json = expect(!binary_to_string(response.body))
  let _ = perform Log(json)
  tokenise([], json)
}",
    ),
  ]
}
