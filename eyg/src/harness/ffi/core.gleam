import eyg/analysis/typ as t
import eyg/runtime/interpreter as r
import harness/ffi/spec.{
  build, empty, end, integer, lambda, record, string, unbound, union, variant,
}

pub const true = r.Tagged("True", r.Record([]))

pub const false = r.Tagged("False", r.Record([]))

pub const boolean = t.Union(
  t.Extend(
    "True",
    t.Record(t.Closed),
    t.Extend("False", t.Record(t.Closed), t.Closed),
  ),
)

//   t.Extend("True", t.unit, t.Extend("False", t.unit, t.Closed)),

pub fn equal() {
  let el = unbound()
  lambda(
    el,
    lambda(
      el,
      union(variant(
        "True",
        record(empty()),
        variant("False", record(empty()), end()),
      )),
    ),
  )
  |> build(fn(x) {
    fn(y) {
      fn(true) {
        fn(false) {
          case x == y {
            True -> true(Nil)
            False -> false(Nil)
          }
        }
      }
    }
  })
}

external fn stringify(a) -> String =
  "" "JSON.stringify"

pub fn debug() {
  lambda(unbound(), string())
  |> build(fn(x){stringify(x)})
}
