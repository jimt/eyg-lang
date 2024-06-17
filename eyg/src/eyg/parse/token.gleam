pub type Token {
  Whitespace(String)
  Name(String)
  Uppername(String)
  Integer(String)
  String(String)
  Let
  Match
  Perform
  Deep
  Shallow
  Handle
  // Having keyword token instead of using name prevents keywords used as names
  Equal
  Comma
  DotDot
  Dot
  Colon
  RightArrow
  Minus
  Bang
  Bar

  LeftParen
  RightParen
  LeftBrace
  RightBrace
  LeftSquare
  RightSquare

  // Invalid token
  UnexpectedGrapheme(String)
  UnterminatedString(String)
}

pub fn to_string(token) {
  case token {
    Whitespace(raw) -> raw
    Name(raw) -> raw
    Uppername(raw) -> raw
    Integer(raw) -> raw
    String(raw) -> "\"" <> raw <> "\""
    Let -> "let"
    Match -> "match"
    Perform -> "perform"
    Deep -> "deep"
    Shallow -> "shallow"
    Handle -> "handle"
    // Having keyword token instead of using name prevents keywords used as names
    Equal -> "="
    Comma -> ","
    DotDot -> ".."
    Dot -> "."
    Colon -> ":"
    RightArrow -> "->"
    Minus -> "-"
    Bang -> "!"
    Bar -> "|"

    LeftParen -> "("
    RightParen -> ")"
    LeftBrace -> "{"
    RightBrace -> "}"
    LeftSquare -> "["
    RightSquare -> "]"

    // Invalid token
    UnexpectedGrapheme(raw) -> raw
    UnterminatedString(raw) -> raw
  }
}
