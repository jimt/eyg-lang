package main

import "fmt"

type C interface {
	step(E, K) (C, E, K)
}
type Value interface {
	C
	call(Value, E, K) (C, E, K)
	debug() string
}

type E interface {
	get(string) (Value, bool)
	put(string, Value) E
}

// K exists so I don't have to track that I have pointers to the stack
type K interface {
	compute(v Value, e E) (C, E, K)
	done() bool
}

type Lambda struct {
	label string
	body  C
}

func (lambda *Lambda) step(e E, k K) (C, E, K) {
	return &Closure{lambda, e}, e, k
}

type Closure struct {
	lambda *Lambda
	env    E
}

func (closure *Closure) step(e E, k K) (C, E, K) {
	return k.compute(closure, e)
}

func (c *Closure) call(arg Value, _ E, k K) (C, E, K) {
	e := c.env.put(c.lambda.label, arg)
	return c.lambda.body, e, k
}

func (c *Closure) debug() string {
	return fmt.Sprintf("(%s) -> { ... }", c.lambda.label)
}

type Call struct {
	fn  C
	arg C
}

func (exp *Call) step(e E, k K) (C, E, K) {
	return exp.fn, e, &Stack{&Arg{exp.arg, e}, k}
}

type Variable struct {
	label string
}

func (exp *Variable) step(e E, k K) (C, E, K) {
	value, ok := e.get(exp.label)
	if !ok {
		return &Error{&UndefinedVariable{exp.label}}, e, k
	}
	return value, e, k
}

type Let struct {
	label string
	value C
	then  C
}

func (exp *Let) step(e E, k K) (C, E, K) {
	return exp.value, e, &Stack{&Assign{exp.label, exp.then, e}, k}
}

type Assign struct {
	label string
	then  C
	env   E
}

func (k *Assign) compute(value Value, _ E, rest K) (C, E, K) {
	e := k.env.put(k.label, value)
	return k.then, e, rest
}

type Arg struct {
	value C
	env   E
}

func (k *Arg) compute(value Value, _ E, rest K) (C, E, K) {
	return k.value, k.env, &Stack{&Apply{value, k.env}, rest}
}

type Apply struct {
	fn  Value
	env E
}

func (k *Apply) compute(value Value, env E, rest K) (C, E, K) {
	return k.fn.call(value, k.env, rest)
}

type Vacant struct {
	comment string
}

var _ C = (*Vacant)(nil)

func (v *Vacant) step(e E, k K) (C, E, K) {
	return &Error{&NotImplemented{v.comment}}, e, k
}

func eval(c C, k K) (Value, *Error) {
	var e E = emptyEnv()
	for {
		c, e, k = c.step(e, k)
		if err, ok := c.(*Error); ok {
			return nil, err
		}
		if value, ok := c.(Value); ok && k.done() {
			return value, nil
		}
	}
}
