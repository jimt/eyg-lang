package main

import (
	"fmt"
	"strings"
)

type Empty struct{}

func (value *Empty) step(e E, k K) (C, E, K) {
	return k.compute(value, e)
}

func (value *Empty) call(_arg Value, e E, k K) (C, E, K) {
	return &Error{&NotAFunction{value}}, e, k
}

func (value *Empty) debug() string {
	return "{}"
}

type Extend struct {
	label string
	item  Value
	// improper record possible
	rest Value
}

func (value *Extend) step(e E, k K) (C, E, K) {
	return k.compute(value, e)
}

func (value *Extend) call(arg Value, e E, k K) (C, E, K) {
	if value.item == nil {
		new := *value
		new.item = arg
		return &new, e, k
	}
	if value.rest == nil {
		new := *value
		new.rest = arg
		return &new, e, k
	}
	return &Error{&NotAFunction{value}}, e, k
}

func (record *Extend) debug() string {
	// return fmt.Sprintf("+%s", value.label)
	items := []string{}
out:
	for {
		if record.item == nil {
			// could be {a .._,_}
			items = append(items, fmt.Sprintf("(%s) ->", record.label))
			break out
		}
		items = append(items, fmt.Sprintf("%s: %s", record.label, record.item.debug()))
		switch r := record.rest.(type) {
		case *Extend:
			record = r
		case *Empty:
			break out
		case nil:
			items = append(items, ".._")
			break out
		default:
			items = append(items, fmt.Sprintf("..%s", r.debug()))
			break out
		}
	}
	return fmt.Sprintf("{%s}", strings.Join(items, ", "))
}

type Select struct {
	label string
}

func (record *Select) step(e E, k K) (C, E, K) {
	return k.compute(record, e)
}

func (value *Select) call(arg Value, e E, k K) (C, E, K) {
	intitial := arg
	for {
		switch a := arg.(type) {
		case *Empty:
			fmt.Printf("env in select %#v", e)
			return &Error{&MissingField{value.label, intitial}}, e, k
		case *Extend:
			if a.label == value.label {
				return a.item, e, k
			}
			arg = a.rest
			continue
		default:
			return &Error{&NotARecord{arg}}, e, k
		}
	}
}

func (value *Select) debug() string {
	return fmt.Sprintf(".%s", value.label)
}

type Overwrite struct {
	label string
	item  Value
}

func (record *Overwrite) step(e E, k K) (C, E, K) {
	return k.compute(record, e)
}

func (value *Overwrite) call(arg Value, e E, k K) (C, E, K) {
	if value.item == nil {
		new := *value
		new.item = arg
		return &new, e, k
	}
	return &Extend{value.label, value.item, arg}, e, k
}

func (value *Overwrite) debug() string {
	return fmt.Sprintf(":=%s", value.label)
}

func field(value Value, f string) (Value, bool) {
	record, ok := value.(*Extend)
	if !ok {
		return nil, false
	}
	if record.label == f {
		return record.item, true
	}
	return field(record.rest, f)
}
