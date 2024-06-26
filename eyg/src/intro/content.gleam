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
    #(
      h.div([], [text("json")]),
      "let { list, keylist, string } = #standard_library

let digits = [\"1\", \"2\", \"3\", \"4\", \"5\", \"6\", \"7\", \"8\", \"9\", \"0\"]
let whitespace = [\" \", \"\r\n\", \"\n\",\"\r\", \"\t\"]
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

let read_number = !fix((read_number, gathered, rest) -> { 
  match string.pop_grapheme(rest) {
    Ok({head, tail}) -> { 
      match list.contains([\".\", ..digits], head) {
        True(_) -> { read_number(string.append(gathered, head), tail) }
        False(_) -> { {gathered, rest} }
      }
    }
    Error(_) -> { {gathered, rest} }
  }
})

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
                      Error(_) -> { 
                        match list.contains([\"-\", ..digits], head) {
                          True(_) -> { 
                            let {gathered, rest} = read_number(head, tail)
                            tokenise([Number(gathered), ..acc], rest)
                          }
                          False(_) -> { tokenise([IllegalCharachter(head), ..acc], tail) }
                        }
                      }
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
  tokenise([],\"{
    \\\"results\\\": {
        \\\"date\\\": \\\"2024-06-26\\\",
        \\\"sunrise\\\": \\\"5:45:46 AM\\\",
        \\\"sunset\\\": \\\"8:38:48 PM\\\",
        \\\"first_light\\\": \\\"3:46:58 AM\\\",
        \\\"last_light\\\": \\\"10:37:36 PM\\\",
        \\\"dawn\\\": \\\"5:13:44 AM\\\",
        \\\"dusk\\\": \\\"9:10:50 PM\\\",
        \\\"solar_noon\\\": \\\"1:12:17 PM\\\",
        \\\"golden_hour\\\": \\\"7:58:53 PM\\\",
        \\\"day_length\\\": \\\"14:53:01\\\",
        \\\"timezone\\\": \\\"America/New_York\\\",
        \\\"utc_offset\\\": -240
    },
    \\\"status\\\": \\\"OK\\\"
}\")
} ",
    ),
    #(
      h.div([], [text("parseing")]),
      "let { list, debug } = #standard_library
      
let string = (k, tokens) -> {
  !uncons(tokens,
    (_) -> { Error(UnexpectedEnd({})) },
    (token, rest) -> { match token {
      String(raw) -> { k(raw, rest) }
      |(_) -> { Error(UnexpectedToken(token)) }
    } }
  )
}

let integer = (k, tokens) -> {
  !uncons(tokens,
    (_) -> { Error(UnexpectedEnd({})) },
    (token, rest) -> { match token {
      Number(raw) -> { k(raw, rest) }
      |(_) -> { Error(UnexpectedToken(token)) }
    } }
  )
}

let done = (_) -> { todo123}
let object = (_) -> { todorr23 }

let list_element = !fix((list_element, decoder, k, acc, rest) -> { 
  !uncons(rest,
    (_) -> { Error(UnexpectedEnd({})) },
    (token, rest) -> { match token {
      Comma(_) -> { 
        decoder((out, after) -> { list_element(decoder, k, [out, ..acc], after) }, rest) 
      }
      RightBracked(_) -> { 
        k(list.reverse(acc), rest) 
      }
      |(_) -> { Error(UnexpectedToken(token)) }
    } }
  )
})

let as_list = (decoder, k, tokens) -> {
  !uncons(tokens,
    (_) -> { Error(UnexpectedEnd({})) },
    (token, rest) -> { match token {
      LeftBracked(_) -> { !uncons(rest,
        (_) -> { Error(UnexpectedEnd({})) },
        (token, final) -> { match token {
          RightBracked(_) -> { k([], final) }
          |(_) -> {
            decoder((out, after) -> { list_element(decoder, k, [out], after) }, rest)
          }
        }}
      )}
      |(_) -> { Error(UnexpectedToken(token)) }
    } }
  )
}

let parse = (decoder, raw) -> {
  decoder((out,_rest) -> { out }, tokenise([], raw))
}

let do_dynamic = !fix((do_dynamic, rest, k) -> {
  let take_elements = !fix((take_elements, k, acc, rest) -> {
    !uncons(rest,
      (_) -> { Error(UnexpectedEnd({})) },
      (token, rest) -> { match token {
        Comma(_) -> { 
          do_dynamic(rest, (element, rest) -> { take_elements(k, [element, ..acc], rest) })
        }
        RightBracked(_) -> { 
          k(Array(list.reverse(acc)), rest) 
        }
        |(_) -> { Error(UnexpectedToken(token)) }
      } }
    )
  })

  !uncons(rest,
    (_) -> { Error(UnexpectedEnd({})) },
    (token, rest) -> { match token {
      Number(raw) -> { k(Number(raw), rest) }
      String(raw) -> { k(String(raw), rest) }
      True(raw) -> { k(True(raw), rest) }
      False(raw) -> { k(False(raw), rest) }
      Null(raw) -> { k(Null(raw), rest) }
      LeftBracked(_) -> { !uncons(rest,
        (_) -> { Error(UnexpectedEnd({})) },
        (token, final) -> { match token {
          RightBracked(_) -> { k(Array([]), final) }
          |(_) -> {
            do_dynamic(rest, (element, rest) -> { take_elements(k, [element], rest) })
          }
        }}
      )}
      |(_) -> { Error(UnexpectedToken(token)) }
    }}
  )
})

let dynamic = !fix((dynamic, raw) -> {
  let tokens = tokenise([], raw)
  do_dynamic(tokens, (value,remaining) -> { Ok(value) })
})

let run = (_) -> {
  let _ = perform Log(parse(string, \"\\\"foo\\\"\"))
  let _ = perform Log(debug(tokenise([], \"[]\")))
  let _ = parse(as_list(integer), \"[]\")
  dynamic(\"[1, true]\")
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
    #(
      h.div([], [text("cat")]),
      "let { debug } = #standard_library

let run = (_) -> {
  let _ = perform Log(debug(!string_to_binary(\"\\\"\")))
  let request = http.get(\"catfact.ninja\")
  let request = {
    path: \"/fact\",
    query: None({}),
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
