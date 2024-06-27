import gleam/list
import gleam/string

pub fn line_count(content) {
  string.split(content, "\n")
  |> list.length
}

pub fn line_offsets(source) {
  list.reverse(do_lines(source, 0, 0, []))
}

// could be done with a nonempty list as the accumulator 
// return non empty list would give coloum easy
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
          let offset = offset + string.byte_size(g)
          do_lines(rest, offset, start, acc)
        }
        Error(Nil) -> [start, ..acc]
      }
  }
}

pub fn offset_line_number(code, offset) {
  line_offsets(code)
  |> list.take_while(fn(x) { x <= offset })
  |> list.length
}
