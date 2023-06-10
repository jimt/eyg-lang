import gleam/list
import gleam/listx
import gleam/string

pub fn insert_at(original, at, new) {
  string.to_graphemes(original)
  |> listx.insert_at(at, string.to_graphemes(new))
  |> string.concat
}

pub fn replace_at(original, from, to, new) {
  let letters = string.to_graphemes(original)
  let pre = list.take(letters, from)
  let post = list.drop(letters, to)
  list.flatten([pre, string.to_graphemes(new), post])
  |> string.concat
}

pub external fn fold_graphmemes(String, a, fn(a, String) -> a) -> a =
  "../plinth_ffi.js" "foldGraphmemes"

pub external fn index_fold_graphmemes(String, a, fn(a, String, Int) -> a) -> a =
  "../plinth_ffi.js" "foldGraphmemes"
