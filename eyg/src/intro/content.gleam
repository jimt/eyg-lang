import lustre/attribute as a
import lustre/element.{fragment, none, text} as _
import lustre/element/html as h

pub fn pages() {
  [
    #("intro", [
      #(
        h.div([], [text("cat")]),
        "let { debug } = #h1c86c927
let http = #h85a585d
let task = #h67a13d96
let json = #hd76acaa1

let run = (_) -> {
  let request = http.get(\"catfact.ninja\", \"/fact\", None({}))
  let response = task.fetch(request)

  let decoder = json.object(json.field(\"fact\", json.string, json.done), (fact) -> { fact })
  json.parse_bytes(decoder, response)
}",
      ),
      #(h.p([], [text("whats the point")]), "let x = todo"),
      #(
        h.p([], [text("whats the point")]),
        "let { string } = #h1c86c927

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
        "let { string } = #h1c86c927
  let run = (_) -> { 
    let a = match perform Geo({}) {
      Ok({latitude,longitude}) -> { {latitude,longitude} }
     }
    let _ = perform Wait(5000)
    a
  }",
      ),
    ]),
    #("http", [
      #(
        h.p([], [text("constants")]),
        "let http = HTTP({})
let https = HTTPS({})


",
      ),
      #(
        h.p([], [text("building requests")]),
        "let build_request = (method, scheme, host, port, path, query, headers, body) -> {
  {method, scheme, host, port, path, query, headers, body}
}

let get = (host, path, query) -> {
  build_request(GET({}), https, host, None({}), path, query, [], !string_to_binary(\"\"))
}
",
      ),
    ]),
    #("task", [
      #(
        h.div([], [text("task")]),
        "let { equal, debug } = #h1c86c927
    
let fetch = (request) -> {
  match perform Await(perform Fetch(request)) {
    Ok({status, body}) -> { match equal(status, 200) {
      True(_) -> { body }
      False(_) -> { perform Abort(\"request returned not OK status\") }
    } }
    Error(reason) -> { perform Abort(reason) }
  }
}",
      ),
    ]),
    #("json", [
      #(
        h.div([], [text("json")]),
        "let { list, keylist, string } = #h1c86c927

let digits = [\"1\", \"2\", \"3\", \"4\", \"5\", \"6\", \"7\", \"8\", \"9\", \"0\"]
let whitespace = [\" \", \"\r\n\", \"\n\",\"\r\", \"\t\"]

let literal = [
  {key: \"{\", value: LeftBrace({})},
  {key: \"}\", value: RightBrace({})},
  {key: \"[\", value: LeftBracket({})},
  {key: \"]\", value: RightBracket({})},
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
})([])
let run = (_) -> {
  tokenise(\"{
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
    }\"
  )
}",
      ),
      #(
        fragment([h.h2([a.id("flat")], [text("Flat representation")])]),
        "let { list, keylist, string } = #h1c86c927

let take = (tokens, then) -> {
  !uncons(tokens, (_) -> { Error(UnexpectedEnd({})) }, then)
}

let read_field = !fix((read_field, flat, acc, stack, tokens) -> {
  take(tokens, (token, tokens) -> {
    match token {
      RightBrace(_) -> { todo }
      String(raw) -> { 
        take(tokens, (token, tokens) -> {
          match token {
            Colon(_) -> {
              let depth = list.length(stack)
              let acc = [{term: Field(raw), depth},..acc]
              flat(acc, stack, tokens)
            }
            |(_) -> { Error(UnexpectedEnd({}))  }
          }
        })
      }
      |(_) -> { Error(UnexpectedEnd({}))  }
    }
  })
})


let flat = !fix((flat, acc, stack, tokens) -> {
  !uncons(tokens, (_) -> { Error(UnexpectedEnd({})) }, (token, tokens) -> {
    let depth = list.length(stack)
    let k = (acc, stack) -> { 
      !uncons(stack, (_) -> { Ok(list.reverse(acc)) },(_,_) -> { flat(acc, stack, tokens) })
    }
    match token {
      True(_) -> { k([{term: True({}), depth}, ..acc], stack) }
      False(_) -> { k([{term: False({}), depth}, ..acc], stack) }
      Null(_) -> { k([{term: Null({}), depth}, ..acc], stack) }
      Number(raw) -> { k([{term: Number(raw), depth}, ..acc], stack) }
      String(raw) -> { k([{term: String(raw), depth}, ..acc], stack) }
      LeftBracket(_) -> {
        k([{term: List({}), depth}, ..acc], [List({}), ..stack])
      }
      RightBracket(_) -> {
        !uncons(stack, (_) -> { Error(UnexpectedToken(token)) }, (current, stack) -> { 
          match current {
            List(_) -> { k(acc, stack) }
            |(_) -> { Error(UnexpectedToken(token)) }
          }
        })
      }
      LeftBrace(_) -> {
        read_field(flat, [{term: Object({}), depth}, ..acc], [Object({}), ..stack], tokens)
      }
      RightBrace(_) -> {
        !uncons(stack, (_) -> { Error(UnexpectedToken(token)) }, (current, stack) -> { 
          match current {
            Object(_) -> { k(acc, stack) }
            |(_) -> { Error(UnexpectedToken(token)) }
          }
        })
      }
      Comma(_) -> {
        !uncons(stack, (_) -> { Error(UnexpectedToken(token)) }, (current,_) -> { 
          match current {
            List(_) -> { k(acc, stack) }
            Object(_) -> { read_field(flat, acc, stack, tokens) }
            |(_) -> { Error(UnexpectedToken(token)) }
          }
        })
      }
      |(other) -> { Error(UnexpectedToken(other)) }
    }
    
  })
})([],[])

let a = (_) -> {
  let tokens = tokenise(\"{}\")
  flat(tokens)
}

let a = (_) -> {
  let tokens = tokenise(\"{\\\"b\\\":5,\\\"c\\\":{\\\"x\\\":5}}\")
  flat(tokens)
}


let run = (_) -> {
  let tokens = tokenise(\"[1,2]\")
  flat(tokens)
}",
      ),
      #(
        fragment([h.h2([a.id("parse")], [text("Parsing")])]),
        "let { equal, debug } = #h1c86c927


let boolean = (flattened) -> {
  !uncons(flattened, (_) -> { Error(UnexpectedEnd({})) }, ({term}, rest) -> {
    match term {
      True(_) -> { Ok({value: True({}), rest}) }
      False(_) -> { Ok({value: False({}), rest})}
      |(other) -> { Error(UnexpectedTerm(other)) }
    }
  })
}

let integer = (flattened) -> {
  !uncons(flattened, (_) -> { Error(UnexpectedEnd({})) }, ({term}, rest) -> {
    match term {
      Number(raw) -> { match !int_parse(raw) {
        Ok(value) -> { Ok({value: value, rest}) }
        |(other) -> { Error(NotAnInteger(raw)) }
      } }
      |(other) -> { Error(UnexpectedTerm(other)) }
    }
  })
}

let string = (flattened) -> {
  !uncons(flattened, (_) -> { Error(UnexpectedEnd({})) }, ({term}, rest) -> {
    match term {
      String(raw) -> { Ok({value: raw, rest}) }
      |(other) -> { Error(UnexpectedTerm(other)) }
    }
  })
}

let lookup = !fix((lookup, flattened, field, under) -> {
  take(flattened, ({term, depth}, flattened) -> {
    match !int_compare(depth, under) {
      Lt(_) -> { Error(UnknownField(field)) }
      Eq(_) -> {
        match term {
          Field(f) -> { 
            match equal(f, field) {
              True(_) -> { Ok(flattened) }
              False(_) -> { lookup(flattened, field, under) }
            }
          }
          |(other) -> { lookup(flattened, field, under) }
        }
      }
      Gt(_) -> { lookup(flattened, field, under) }
    }

  })
})

let fetch_field = (flattened, field) -> {
  take(flattened, ({term, depth}, rest) -> {
    match term {
      Object(raw) -> { lookup(rest, field, !int_add(depth, 1)) }
      |(other) -> { Error(UnexpectedTerm(other)) }
    }
  })
}

let expect = (result) -> {
  match result {
    Ok(value) -> { value }
    Error(reason) -> { perform Abort(reason) }
  }
}


let a = (_) -> {
  let tokens = tokenise(\"{\\\"b\\\":5,\\\"c\\\":{\\\"x\\\":5}}\")
  let flattened =  expect(flat(tokens))
  let _ = perform Log(debug(flattened))
  field(flattened, \"c\")
}


let drop = !fix((drop, flattened, under) -> {
  !uncons(flattened, (_) -> { [] }, ({term, depth}, flattened) -> {
    match !int_compare(depth, under) {
      Lt(_) -> { flattened }
      |(_) -> { drop(flattened, under) }
    }

  })
})

let done = (builder,depth,flattened) -> {
  Ok({value: builder, rest: drop(flattened, depth)})
}

let field = (label, decoder, next, builder, level, flattened) -> {
  match lookup(flattened, label, level) {
    Ok(rest) -> { match decoder(rest) {
      Ok({value}) -> { next(builder(value), level, flattened) }
      |(other) -> { other }
    } }
    |(other) -> { other }
  }
}

let object = (fields, builder, flattened) -> {
  take(flattened, ({term, depth}, rest) -> {
    match term {
      Object(raw) -> { match fields(builder, !int_add(depth, 1), rest) {
        Ok(inner) -> { Ok(inner) }
        |(other) -> { other }
      }}
      |(other) -> { Error(UnexpectedTerm(other)) }
    }
  })
}

let a = (_) -> {
  let tokens = tokenise(\"{\\\"b\\\":5,\\\"c\\\":{\\\"x\\\":5}}\")
  let flattened =  expect(flat(tokens))
  let _ = perform Log(debug(flattened))
  let decoder = object(field(\"b\", integer, done), (x) -> { x })
  decoder(flattened)
}
 
let l = (decoder, rest) -> {
  !uncons(rest, (_) -> { Error(UnexpectedEnd({})) }, ({term, depth}, rest) -> {
    match term {
      List(_) -> {
        !fix((pull, acc, rest)-> {
          !uncons(rest, (_) -> { 
            Ok({value: list.reverse(acc), rest}) 
          }, ({depth: next},_)-> {
            match !int_compare(next, depth) {
              Gt(_) -> { match decoder(rest) {
                Ok({value, rest}) -> { pull([value,..acc], rest) }
                Error(reason) -> { Error(reason) }
              } }
              Lt(_) -> { Ok({value: list.reverse(acc), rest}) }
            }
          })
        })([], rest)
      }
      |(other) -> { Error(UnexpectedTerm(other)) }
    }
  })
}
",
      ),
      #(
        fragment([]),
        "let { debug } = #h1c86c927
let parse = (decoder, raw) -> {
  let flattened = flat(tokenise(raw))
  let _ = perform Log(debug(flattened))
  match flattened {
    Ok(flat) -> { match decoder(flat) {
      Ok({value}) -> { Ok(value) }
      Error(reason) -> { Error(reason) }
    } }
    Error(reason) -> { Error(reason) }
  }
}
 
let parse_bytes = (decoder, bytes) -> {
  
  match !binary_to_string(bytes) {
    Ok(string) -> { match flat(tokenise(string)) {
      Ok(flattened) -> { match decoder(flattened) {
        Ok({value}) -> { Ok(value) }
        |(other) -> { other }
      } }
      |(other) -> { other }
    } }
    |(other) -> { other }
  }
}

let run = (_) -> {
  let _ = parse(l(boolean), \"[true]\")
   parse(l(integer), \"[2]\")
}",
      ),
    ]),
    //     #(

  // "

  // } ",
  //     ),
  //     #(
  //       h.div([], [text("parseing")]),
  //       "let { list, debug, equal } = #h1c86c927

  // let string = (k, tokens) -> {
  //   !uncons(tokens,
  //     (_) -> { Error(UnexpectedEnd({})) },
  //     (token, rest) -> { match token {
  //       String(raw) -> { k(raw, rest) }
  //       |(_) -> { Error(UnexpectedToken(token)) }
  //     } }
  //   )
  // }

  // let integer = (k, tokens) -> {
  //   !uncons(tokens,
  //     (_) -> { Error(UnexpectedEnd({})) },
  //     (token, rest) -> { match token {
  //       Number(raw) -> { k(raw, rest) }
  //       |(_) -> { Error(UnexpectedToken(token)) }
  //     } }
  //   )
  // }

  // let pop = (items, or) -> {
  //   !uncons(items,
  //     (_) -> { perform Abort(or) },
  //     (token, rest) -> { {token, rest} }
  //   )
  // }

  // let take = (tokens) -> { pop(tokens, UnexpectedEnd({})) }

  // let drop_item = !fix((drop_item, rest) -> {
  //   let {token, rest} = take(rest)
  //   match token {
  //     LeftBracket(_) -> {
  //       let {token, rest} = take(rest)
  //       match token {
  //         RightBracket(_) -> { rest }
  //         |(_) -> {
  //           let rest = drop_item(rest)
  //           !fix((drop_element, rest) -> {
  //             let {token, rest} = take(rest)
  //             match token {
  //               RightBracket(_) -> { rest }
  //               Comma(_) -> { 
  //                 let rest = drop_item(rest)
  //                 drop_element(rest)
  //               }
  //               |(_) -> { perform Abort(UnexpectedToken(token)) }
  //             }
  //           }, rest)
  //         }
  //       }
  //     }

  //     LeftBrace({}) -> {
  //       let {token, rest} = take(rest)
  //       match token {
  //         RightBrace(_) -> { rest }
  //         String(_) -> { 
  //           let {token, rest} = take(rest)
  //           let rest = match token {
  //             Colon(_) -> { rest }
  //             |(_) -> { perform Abort(UnexpectedToken(token)) }
  //           }
  //           let rest = drop_item(rest)
  //           !fix((drop_field, rest) -> {
  //             let {token, rest} = take(rest)
  //             match token {
  //               RightBrace(_) -> { rest }
  //               Comma(_) -> { 
  //                 let {token, rest} = take(rest)
  //                 let rest = match token {
  //                   String(_) -> { rest }
  //                   |(_) -> { perform Abort(UnexpectedToken(token)) }
  //                 }
  //                 let {token, rest} = take(rest)
  //                 let rest = match token {
  //                   Colon(_) -> { rest }
  //                   |(_) -> { perform Abort(UnexpectedToken(token)) }
  //                 }
  //                 let rest = drop_item(rest)
  //                 drop_field(rest)
  //               }
  //               |(_) -> { perform Abort(UnexpectedToken(token)) }
  //             }
  //           }, rest)
  //         }
  //         |(_) -> { perform Abort(UnexpectedToken(token)) }
  //       }
  //     }
  //     |(_)-> { rest }
  //   }
  // })

  // let done = (value, tokens) -> {
  //   let {token, rest} = take(tokens)
  //   match token {
  //     RightBrace(_) -> { {value, rest} }
  //     String(_) -> { 
  //       let tokens = [LeftBrace({}),..tokens]
  //       let rest = drop_item(tokens)
  //       {value, rest}
  //     }
  //     |(_) -> { perform Abort(UnexpectedToken(token)) }
  //   } 
  // }
  // let _ = \"jump to the correct key\"

  // let field = (key, decoder, builder, tokens) -> { 
  //   let {token, rest} = take(tokens)
  //   match token {
  //     String(found) -> { match equal(found, key) {
  //       True(_) -> { decoder((out,_after) -> { builder(out, tokens) }) }
  //       False(_) -> { tododropcolonvaluecommaif_error_end_and_no_field }
  //     }}
  //     |(_) -> { perform Abort(UnexpectedToken(token)) }
  //   }
  // }

  // let object = (decoder, builder, tokens) -> {
  //   let {token, rest} = take(tokens)
  //   match token {
  //     LeftBrace(_) -> { decoder(builder, rest) }
  //     |(_) -> { perform Abort(UnexpectedToken(token)) }
  //   }
  // }

  // let empty_decoder = (raw) -> {
  //   let d = object(done, \"empty\")
  //   d(tokenise([], raw))
  // }

  // let a_decoder = (raw) -> {
  //   let d = object(field(\"a\", integer, done), (a) -> { a })
  //   d(tokenise([], raw))
  // }

  // let list_element = !fix((list_element, decoder, k, acc, rest) -> { 
  //   !uncons(rest,
  //     (_) -> { Error(UnexpectedEnd({})) },
  //     (token, rest) -> { match token {
  //       Comma(_) -> { 
  //         decoder((out, after) -> { list_element(decoder, k, [out, ..acc], after) }, rest) 
  //       }
  //       RightBracket(_) -> { 
  //         k(list.reverse(acc), rest) 
  //       }
  //       |(_) -> { Error(UnexpectedToken(token)) }
  //     } }
  //   )
  // })

  // let as_list = (decoder, k, tokens) -> {
  //   !uncons(tokens,
  //     (_) -> { Error(UnexpectedEnd({})) },
  //     (token, rest) -> { match token {
  //       LeftBracket(_) -> { !uncons(rest,
  //         (_) -> { Error(UnexpectedEnd({})) },
  //         (token, final) -> { match token {
  //           RightBracket(_) -> { k([], final) }
  //           |(_) -> {
  //             decoder((out, after) -> { list_element(decoder, k, [out], after) }, rest)
  //           }
  //         }}
  //       )}
  //       |(_) -> { Error(UnexpectedToken(token)) }
  //     } }
  //   )
  // }

  // let parse = (decoder, raw) -> {
  //   decoder((out,_rest) -> { out }, tokenise([], raw))
  // }

  // let run = (_) -> {
  //   let _ = perform Log(parse(string, \"\\\"foo\\\"\"))
  //   let _ = perform Log(debug(tokenise([], \"[]\")))
  //   let _ = perform Log(debug(empty_decoder(\"{}\")))
  //   let _ = perform Log(debug(empty_decoder(\"{\\\"a\\\": 5}\")))
  //   let _ = perform Log(debug(a_decoder(\"{\\\"a\\\": 5}\")))
  //   let _ = parse(as_list(integer), \"[]\")
  //   2
  // }",
  //     ),
  //     #(
  //       h.div([], [text("Dyamic")]),
  //       "let do_dynamic = !fix((do_dynamic, rest, k) -> {
  //   let take_elements = !fix((take_elements, k, acc, rest) -> {
  //     !uncons(rest,
  //       (_) -> { Error(UnexpectedEnd({})) },
  //       (token, rest) -> { match token {
  //         Comma(_) -> { 
  //           do_dynamic(rest, (element, rest) -> { take_elements(k, [element, ..acc], rest) })
  //         }
  //         RightBracket(_) -> { 
  //           k(Array(list.reverse(acc)), rest) 
  //         }
  //         |(_) -> { Error(UnexpectedToken(token)) }
  //       } }
  //     )
  //   })

  //   !uncons(rest,
  //     (_) -> { Error(UnexpectedEnd({})) },
  //     (token, rest) -> { match token {
  //       Number(raw) -> { k(Number(raw), rest) }
  //       String(raw) -> { k(String(raw), rest) }
  //       True(raw) -> { k(True(raw), rest) }
  //       False(raw) -> { k(False(raw), rest) }
  //       Null(raw) -> { k(Null(raw), rest) }
  //       LeftBracket(_) -> { !uncons(rest,
  //         (_) -> { Error(UnexpectedEnd({})) },
  //         (token, final) -> { match token {
  //           RightBracket(_) -> { k(Array([]), final) }
  //           |(_) -> {
  //             do_dynamic(rest, (element, rest) -> { take_elements(k, [element], rest) })
  //           }
  //         }}
  //       )}
  //       |(_) -> { Error(UnexpectedToken(token)) }
  //     }}
  //   )
  // })

  // let dynamic = !fix((dynamic, raw) -> {
  //   let tokens = tokenise([], raw)
  //   do_dynamic(tokens, (value,remaining) -> { Ok(value) })
  // })

  // let run = (_) -> {
  //   dynamic(\"[1, true]\")
  // }",
  //     ),
  //     #(
  //       h.div([], [text("HTTP")]),
  //       "let { http, mime, string } = #h1c86c927

  // let expect = (result) -> {
  //   match result {
  //     Ok(value) -> { value }
  //     Error(reason) -> { perform Abort(reason) }
  //   }
  // }

  // let run = (_) -> {
  //   let request = http.get(\"api.sunrisesunset.io\")
  //   let request = {
  //     path: \"/json\",
  //     query: Some(\"lat=38.907192&lng=-77.036873\"),
  //     body: !string_to_binary(\"\"),
  //     ..request}
  //   let response = expect(perform Await(perform Fetch(request)))

  //   let json = expect(!binary_to_string(response.body))
  //   let _ = perform Log(json)
  //   tokenise([], json)
  // }",
  //     ),
  ]
}
