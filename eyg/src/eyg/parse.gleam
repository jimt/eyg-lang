import eyg/parse/lexer
import eyg/parse/parser
import eyg/parse/token
import eygir/annotated as e
import gleam/io
import gleam/list
import gleam/option.{None, Some}

pub fn from_string(src) {
  src
  |> lexer.lex()
  |> token.drop_whitespace()
  |> parser.expression()
}

pub fn block_from_string(src) {
  let parsed =
    src
    |> lexer.lex()
    |> token.drop_whitespace()
    |> parser.block()
  case parsed {
    Ok(#(exp, left)) -> Ok(#(do_gather(exp, []), left))
    Error(reason) -> Error(reason)
  }
}

fn do_gather(exp, acc) {
  let #(exp, span) = exp
  case exp {
    e.Let(label, value, then) -> do_gather(then, [#(label, value), ..acc])
    e.Vacant(_) -> #(acc, None)
    _ -> #(acc, Some(exp))
  }
}
