import gleam/bit_array
import gleam/list
import gleam/string

pub fn line_count(content) {
  string.split(content, "\n")
  |> list.length
}

pub fn lines_positions(source) {
  list.reverse(do_lines(source, 0, 0, []))
}

fn do_lines(source, offset, start, acc) {
  case source {
    "\r\n" <> rest -> {
      let offset = offset + 2
      do_lines(rest, offset, offset, [start, ..acc])
    }
    "\n" <> rest -> {
      let offset = offset + 1
      do_lines(rest, offset, offset, [start, ..acc])
    }
    _ ->
      case string.pop_grapheme(source) {
        Ok(#(g, rest)) -> {
          let offset = offset + byte_size(g)
          do_lines(rest, offset, start, acc)
        }
        Error(Nil) -> [start, ..acc]
      }
  }
}

fn byte_size(string: String) -> Int {
  bit_array.byte_size(<<string:utf8>>)
}
