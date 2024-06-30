import eyg/analysis/type_/binding
import eyg/analysis/type_/binding/error
import eyg/analysis/type_/isomorphic as t
import gleam/dict
import gleam/int
import gleam/result.{try}

pub fn unify(t1, t2, level, bindings) {
  do_unify(t1, t2, level, bindings, Ok)
}

fn do_unify(
  t1,
  t2,
  level,
  bindings,
  k: fn(dict.Dict(Int, binding.Binding)) ->
    Result(dict.Dict(Int, binding.Binding), _),
) -> Result(dict.Dict(Int, binding.Binding), _) {
  case t1, find(t1, bindings), t2, find(t2, bindings) {
    t.Var(i), _, t.Var(j), _ if i == j -> k(bindings)
    _, Ok(binding.Bound(t1)), _, _ -> do_unify(t1, t2, level, bindings, k)
    _, _, _, Ok(binding.Bound(t2)) -> do_unify(t1, t2, level, bindings, k)
    t.Var(i), Ok(binding.Unbound(level)), other, _
    | other, _, t.Var(i), Ok(binding.Unbound(level))
    -> {
      use bindings <- try(occurs_and_levels(i, level, other, bindings, Ok))
      k(dict.insert(bindings, i, binding.Bound(other)))
    }
    t.Fun(arg1, eff1, ret1), _, t.Fun(arg2, eff2, ret2), _ -> {
      use bindings <- do_unify(arg1, arg2, level, bindings)
      use bindings <- do_unify(eff1, eff2, level, bindings)
      do_unify(ret1, ret2, level, bindings, k)
    }
    t.Integer, _, t.Integer, _ -> k(bindings)
    t.Binary, _, t.Binary, _ -> k(bindings)
    t.String, _, t.String, _ -> k(bindings)

    t.List(el1), _, t.List(el2), _ -> do_unify(el1, el2, level, bindings, k)
    t.Empty, _, t.Empty, _ -> k(bindings)
    t.Record(rows1), _, t.Record(rows2), _ ->
      do_unify(rows1, rows2, level, bindings, k)
    t.Union(rows1), _, t.Union(rows2), _ ->
      do_unify(rows1, rows2, level, bindings, k)
    t.RowExtend(l1, field1, rest1), _, other, _
    | other, _, t.RowExtend(l1, field1, rest1), _
    -> {
      use #(field2, rest2, bindings) <- try(rewrite_row(
        l1,
        other,
        level,
        bindings,
        Ok,
      ))
      use bindings <- do_unify(field1, field2, level, bindings)
      do_unify(rest1, rest2, level, bindings, k)
    }
    t.EffectExtend(l1, #(lift1, reply1), r1), _, other, _
    | other, _, t.EffectExtend(l1, #(lift1, reply1), r1), _
    -> {
      use #(#(lift2, reply2), r2, bindings) <- try(rewrite_effect(
        l1,
        other,
        level,
        bindings,
        Ok,
      ))
      use bindings <- do_unify(lift1, lift2, level, bindings)
      use bindings <- do_unify(reply1, reply2, level, bindings)
      do_unify(r1, r2, level, bindings, k)
    }
    t.Promise(t1), _, t.Promise(t2), _ -> do_unify(t1, t2, level, bindings, k)
    _, _, _, _ -> Error(error.TypeMismatch(t1, t2))
  }
}

fn find(type_, bindings) {
  case type_ {
    t.Var(i) -> dict.get(bindings, i)
    _other -> Error(Nil)
  }
}

fn occurs_and_levels(i, level, type_, bindings, k) {
  case type_ {
    t.Var(j) if i == j -> Error(error.Recursive)
    t.Var(j) -> {
      let assert Ok(binding) = dict.get(bindings, j)
      case binding {
        binding.Unbound(l) -> {
          let l = int.min(l, level)
          let bindings = dict.insert(bindings, j, binding.Unbound(l))
          k(bindings)
        }
        binding.Bound(type_) -> occurs_and_levels(i, level, type_, bindings, k)
      }
    }
    t.Fun(arg, eff, ret) -> {
      use bindings <- occurs_and_levels(i, level, arg, bindings)
      use bindings <- occurs_and_levels(i, level, eff, bindings)
      use bindings <- occurs_and_levels(i, level, ret, bindings)
      k(bindings)
    }
    t.Integer -> k(bindings)
    t.Binary -> k(bindings)
    t.String -> k(bindings)
    t.List(el) -> occurs_and_levels(i, level, el, bindings, k)
    t.Record(row) -> occurs_and_levels(i, level, row, bindings, k)
    t.Union(row) -> occurs_and_levels(i, level, row, bindings, k)
    t.Empty -> k(bindings)
    t.RowExtend(_, field, rest) -> {
      use bindings <- occurs_and_levels(i, level, field, bindings)
      use bindings <- occurs_and_levels(i, level, rest, bindings)
      k(bindings)
    }
    t.EffectExtend(_, #(lift, reply), rest) -> {
      use bindings <- occurs_and_levels(i, level, lift, bindings)
      use bindings <- occurs_and_levels(i, level, reply, bindings)
      use bindings <- occurs_and_levels(i, level, rest, bindings)
      k(bindings)
    }
    t.Promise(inner) -> occurs_and_levels(i, level, inner, bindings, k)
  }
}

fn rewrite_row(required, type_, level, bindings, k) {
  case type_ {
    t.Empty -> Error(error.MissingRow(required))
    t.RowExtend(l, field, rest) if l == required -> k(#(field, rest, bindings))
    t.RowExtend(l, other_field, rest) -> {
      use #(field, new_tail, bindings) <- rewrite_row(
        required,
        rest,
        level,
        bindings,
      )
      let rest = t.RowExtend(l, other_field, new_tail)
      k(#(field, rest, bindings))
    }
    t.Var(i) -> {
      // Not sure why this is different to effects
      let #(field, bindings) = binding.mono(level, bindings)
      let #(rest, bindings) = binding.mono(level, bindings)
      let type_ = t.RowExtend(required, field, rest)
      k(#(field, rest, dict.insert(bindings, i, binding.Bound(type_))))
    }
    _ -> panic as "bad row"
  }
}

fn rewrite_effect(required, type_, level, bindings, k) {
  case type_ {
    t.Empty -> Error(error.MissingRow(required))
    t.EffectExtend(l, eff, rest) if l == required -> k(#(eff, rest, bindings))
    t.EffectExtend(l, other_eff, rest) -> {
      use #(eff, new_tail, bindings) <- rewrite_effect(
        required,
        rest,
        level,
        bindings,
      )
      // use #(eff, new_tail, s) <-  try(rewrite_effect(l, rest, s))
      let rest = t.EffectExtend(l, other_eff, new_tail)
      k(#(eff, rest, bindings))
    }
    t.Var(i) -> {
      let #(lift, bindings) = binding.mono(level, bindings)
      let #(reply, bindings) = binding.mono(level, bindings)

      // Might get bound during tail rewrite
      let assert Ok(binding) = dict.get(bindings, i)
      case binding {
        binding.Unbound(level) -> {
          let #(rest, bindings) = binding.mono(level, bindings)

          let type_ = t.EffectExtend(required, #(lift, reply), rest)
          let bindings = dict.insert(bindings, i, binding.Bound(type_))
          k(#(#(lift, reply), rest, bindings))
        }
        binding.Bound(type_) ->
          rewrite_effect(required, type_, level, bindings, k)
      }
    }
    // _ -> Error(error.TypeMismatch(EffectExtend(required, type_, t.Empty), type_))
    _ -> panic as "bad effect"
  }
}
