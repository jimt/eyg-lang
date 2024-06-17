import eyg/parse/lexer
import eyg/parse/parser
import eyg/parse/token
import gleam/io

pub fn from_string(src) {
  src
  |> lexer.lex()
  |> token.drop_whitespace()
  |> io.debug
  |> parser.parse()
}
