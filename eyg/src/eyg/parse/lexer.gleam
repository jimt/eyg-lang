import eyg/parse/token as t
import gleam/bit_array
import gleam/list
import gleam/string

pub fn lex(raw) {
  loop(raw, 0, [])
}

fn loop(raw, offset, acc) {
  case pop(raw, offset) {
    Ok(#(token, offset, rest)) -> loop(rest, offset, [token, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}

fn done(at start) {
  fn(t, size, rest) { Ok(#(#(t, start), start + size, rest)) }
}

fn pop(raw, start) {
  let done = done(at: start)

  // If we track whitespace token then can always return original start
  case raw {
    // "\r\n" <> rest -> pop(rest, start + 2)
    // "\n" <> rest | " " <> rest | "\t" <> rest -> pop(rest, start + 1)
    "\r\n" <> rest -> whitespace("\r\n", rest, done)
    "\n" <> rest -> whitespace("\n", rest, done)
    " " <> rest -> whitespace(" ", rest, done)
    "\t" <> rest -> whitespace("\t", rest, done)

    "(" <> rest -> done(t.LeftParen, 1, rest)
    ")" <> rest -> done(t.RightParen, 1, rest)
    "{" <> rest -> done(t.LeftBrace, 1, rest)
    "}" <> rest -> done(t.RightBrace, 1, rest)
    "[" <> rest -> done(t.LeftSquare, 1, rest)
    "]" <> rest -> done(t.RightSquare, 1, rest)

    "=" <> rest -> done(t.Equal, 1, rest)
    "->" <> rest -> done(t.RightArrow, 2, rest)
    "," <> rest -> done(t.Comma, 1, rest)
    ".." <> rest -> done(t.DotDot, 2, rest)
    "." <> rest -> done(t.Dot, 1, rest)
    ":" <> rest -> done(t.Colon, 1, rest)
    "-" <> rest -> done(t.Minus, 1, rest)
    "!" <> rest -> done(t.Bang, 1, rest)
    "|" <> rest -> done(t.Bar, 1, rest)

    "let" <> rest -> done(t.Let, 3, rest)
    "match" <> rest -> done(t.Match, 5, rest)
    "perform" <> rest -> done(t.Perform, 7, rest)
    "deep" <> rest -> done(t.Deep, 4, rest)
    "shallow" <> rest -> done(t.Shallow, 7, rest)
    "handle" <> rest -> done(t.Handle, 6, rest)

    "\"" <> rest -> string("", rest, done)

    "1" <> rest -> integer("1", rest, done)
    "2" <> rest -> integer("2", rest, done)
    "3" <> rest -> integer("3", rest, done)
    "4" <> rest -> integer("4", rest, done)
    "5" <> rest -> integer("5", rest, done)
    "6" <> rest -> integer("6", rest, done)
    "7" <> rest -> integer("7", rest, done)
    "8" <> rest -> integer("8", rest, done)
    "9" <> rest -> integer("9", rest, done)
    "0" <> rest -> integer("0", rest, done)
    _ -> {
      case string.pop_grapheme(raw) {
        Ok(#(g, rest)) ->
          case is_lower_grapheme(g) || g == "_" {
            True -> name(g, rest, done)
            False ->
              case is_upper_grapheme(g) {
                True -> uppername(g, rest, done)
                False -> done(t.UnexpectedGrapheme(g), byte_size(g), rest)
              }
          }
        Error(Nil) -> Error(Nil)
      }
    }
  }
}

fn whitespace(buffer, rest, done) {
  case rest {
    "\r\n" <> rest -> whitespace(buffer <> "\r\n", rest, done)
    "\n" <> rest -> whitespace(buffer <> "\n", rest, done)
    " " <> rest -> whitespace(buffer <> " ", rest, done)
    "\t" <> rest -> whitespace(buffer <> "\t", rest, done)
    _ -> done(t.Whitespace(buffer), byte_size(buffer), rest)
  }
}

fn string(buffer, rest, done) {
  case rest {
    "\"" <> rest -> done(t.String(buffer), byte_size(buffer) + 2, rest)
    "\\" <> rest ->
      case string.pop_grapheme(rest) {
        Ok(#(g, rest)) -> string(buffer <> "\\" <> g, rest, done)
        Error(Nil) -> string(buffer <> "\\", rest, done)
      }
    _ ->
      case string.pop_grapheme(rest) {
        Ok(#(g, rest)) -> string(buffer <> g, rest, done)
        Error(Nil) ->
          done(t.UnterminatedString(buffer), byte_size(buffer) + 1, "")
      }
  }
}

fn name(buffer, raw, done) {
  case string.pop_grapheme(raw) {
    Ok(#(g, rest)) ->
      case is_lower_grapheme(g) || is_digit_grapheme(g) || g == "_" {
        True -> name(buffer <> g, rest, done)
        False -> done(t.Name(buffer), byte_size(buffer), raw)
      }
    Error(Nil) -> done(t.Name(buffer), byte_size(buffer), raw)
  }
}

fn uppername(buffer, raw, done) {
  case string.pop_grapheme(raw) {
    Ok(#(g, rest)) ->
      case
        is_upper_grapheme(g)
        || is_lower_grapheme(g)
        || is_digit_grapheme(g)
        || g == "_"
      {
        True -> uppername(buffer <> g, rest, done)
        False -> done(t.Uppername(buffer), byte_size(buffer), raw)
      }
    Error(Nil) -> done(t.Uppername(buffer), byte_size(buffer), raw)
  }
}

fn integer(buffer, rest, done) {
  case rest {
    "1" <> rest -> integer(buffer <> "1", rest, done)
    "2" <> rest -> integer(buffer <> "2", rest, done)
    "3" <> rest -> integer(buffer <> "3", rest, done)
    "4" <> rest -> integer(buffer <> "4", rest, done)
    "5" <> rest -> integer(buffer <> "5", rest, done)
    "6" <> rest -> integer(buffer <> "6", rest, done)
    "7" <> rest -> integer(buffer <> "7", rest, done)
    "8" <> rest -> integer(buffer <> "8", rest, done)
    "9" <> rest -> integer(buffer <> "9", rest, done)
    "0" <> rest -> integer(buffer <> "0", rest, done)
    _ -> done(t.Integer(buffer), byte_size(buffer), rest)
  }
}

fn byte_size(string: String) -> Int {
  bit_array.byte_size(<<string:utf8>>)
}

fn is_lower_grapheme(grapheme) {
  case grapheme {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z" -> True
    _ -> False
  }
}

fn is_upper_grapheme(grapheme) {
  case grapheme {
    "A"
    | "B"
    | "C"
    | "D"
    | "E"
    | "F"
    | "G"
    | "H"
    | "I"
    | "J"
    | "K"
    | "L"
    | "M"
    | "N"
    | "O"
    | "P"
    | "Q"
    | "R"
    | "S"
    | "T"
    | "U"
    | "V"
    | "W"
    | "X"
    | "Y"
    | "Z" -> True
    _ -> False
  }
}

fn is_digit_grapheme(grapheme) {
  case grapheme {
    "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" | "0" -> True
    _ -> False
  }
}
