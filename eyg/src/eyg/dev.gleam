import eygir/decode
import eygir/encode
import gleam/bit_array
import gleam/io
import gleam/list
import gleam/pair
import gleam/string
import intro/content
import intro/snippet
import midas/task as t

fn build_drafting() {
  use script <- t.do(t.bundle("drafting/app", "run"))
  let files = [#("/drafting.js", <<script:utf8>>)]
  use index <- t.do(t.read("src/drafting/index.html"))
  t.done([#("/drafting/index.html", index), ..files])
}

fn build_examine() {
  use script <- t.do(t.bundle("examine/app", "run"))
  let files = [#("/examine.js", <<script:utf8>>)]
  use index <- t.do(t.read("src/examine/index.html"))
  t.done([#("/examine/index.html", index), ..files])
}

fn build_spotless() {
  use script <- t.do(t.bundle("spotless/app", "run"))
  let files = [#("/spotless.js", <<script:utf8>>)]
  use index <- t.do(t.read("src/spotless/index.html"))
  use prompt <- t.do(t.read("saved/prompt.json"))

  t.done([#("/terminal/index.html", index), #("/prompt.json", prompt), ..files])
}

fn build_intro() {
  use script <- t.do(t.bundle("intro/intro", "run"))

  use index <- t.do(t.read("src/intro/index.html"))
  use style <- t.do(t.read("src/intro/index.css"))
  use stdlib <- t.do(t.read("saved/std.json"))

  let assert Ok(expression) =
    decode.from_json({
      let assert Ok(stdlib) = bit_array.to_string(stdlib)
      stdlib
    })
  let std_hash = snippet.hash_code(string.inspect(expression))
  use Nil <- t.do(t.log(std_hash))

  let #(pages, _content) = content.pages() |> list.unzip
  let store =
    list.map(content.pages(), fn(page) {
      let #(name, sections) = page
      let #(ref, code) = snippet.document_to_code(sections, snippet.empty())
      let content = <<encode.to_json(code):utf8>>
      io.debug(#(name, ref))
      #("/saved/" <> ref <> ".json", content)
    })

  t.done(
    [
      #("/intro.js", <<script:utf8>>),
      // #("/intro/index.html", index),
      #("/intro/index.css", style),
      #("/saved/std.json", stdlib),
      #("/saved/h" <> std_hash <> ".json", stdlib),
      ..list.map(pages, fn(page) {
        #("/guide/" <> page <> "/index.html", index)
      })
    ]
    |> list.append(store),
  )
}

pub fn preview(args) {
  case args {
    ["intro"] -> {
      use files <- t.do(build_intro())

      t.done(files)
    }
    _ -> {
      use drafting <- t.do(build_drafting())
      use examine <- t.do(build_examine())
      use spotless <- t.do(build_spotless())
      use intro <- t.do(build_intro())

      let files = list.flatten([drafting, examine, spotless, intro])
      t.done(files)
    }
  }
}
