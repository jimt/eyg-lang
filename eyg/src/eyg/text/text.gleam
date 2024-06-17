import gleam/list
import gleam/string

pub fn line_count(content) {
  string.split(content, "\n")
  |> list.length
}
