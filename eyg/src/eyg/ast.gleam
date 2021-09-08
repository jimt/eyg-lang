import eyg/ast/pattern.{Pattern}
import eyg/typer/monotype

pub type Node(m) {
  Binary(value: String)
  Tuple(elements: List(Expression(m)))
  Row(fields: List(#(String, Expression(m))))
  Variable(label: String)
  Let(pattern: Pattern, value: Expression(m), then: Expression(m))
  Function(for: String, body: Expression(m))
  Call(function: Expression(m), with: Expression(m))
  Name(
    type_: #(String, #(List(Int), List(#(String, monotype.Monotype)))),
    then: Expression(m),
  )
  Constructor(named: String, variant: String)
  Case(
    named: String,
    value: Expression(m),
    clauses: List(#(String, String, Expression(m))),
  )
  Provider(id: Int, generator: fn(monotype.Monotype) -> Expression(Nil))
}

// m for metadata
pub type Expression(m) =
  #(m, Node(m))

pub fn binary(value) {
  #(Nil, Binary(value))
}

pub fn name(type_, then) {
  #(Nil, Name(type_, then))
}

pub fn call(function, with) {
  #(Nil, Call(function, with))
}

pub fn function(for, body) {
  #(Nil, Function(for, body))
}

pub fn let_(pattern, value, then) {
  #(Nil, Let(pattern, value, then))
}

pub fn case_(named, subject, clauses) {
  #(Nil, Case(named, subject, clauses))
}

pub fn constructor(named, variant) {
  #(Nil, Constructor(named, variant))
}

pub fn tuple_(elements) {
  #(Nil, Tuple(elements))
}

pub fn row(fields) {
  #(Nil, Row(fields))
}

pub fn variable(label) {
  #(Nil, Variable(label))
}

pub fn provider(constructor, id) {
  #(Nil, Provider(constructor, id))
}
