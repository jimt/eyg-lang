import gleam/list
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
  let files = [#("/intro.js", <<script:utf8>>)]
  use index <- t.do(t.read("src/intro/index.html"))
  use style <- t.do(t.read("src/intro/index.css"))
  use stdlib <- t.do(t.read("saved/std.json"))
  use json <- t.do(t.read("saved/json.json"))

  t.done([
    #("/intro/index.html", index),
    #("/intro/index.css", style),
    #("/saved/std.json", stdlib),
    #("/saved/json.json", json),
    ..files
  ])
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
