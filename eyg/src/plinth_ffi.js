import { Ok, Error } from "./gleam.mjs";

export function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export function onClick(f) {
  document.onclick = function (event) {
    let arg = event.target.closest("[data-click]")?.dataset?.click;
    // can deserialize in language
    if (arg) {
      f(arg);
    }
  };
}

export function onKeyDown(f) {
  document.onkeydown = function (event) {
    // let arg = event.target.closest("[data-keydown]")?.dataset?.click;
    // can deserialize in language
    // event.key
    // if (arg) {
    f(event.key);
    // }
  };
}

// -------- document --------

// could use array from in Gleam code but don't want to return dynamic to represent elementList
// directly typing array of elements is cleanest
export function querySelectorAll(query) {
  return Array.from(document.querySelectorAll(query));
}

export function setAttribute(element, name, value) {
  element.setAttribute(name, value);
}

export function append(parent, child) {
  parent.append(child);
}

export function insertAfter(e, text) {
  e.insertAdjacentHTML("afterend", text);
}

export function insertElementAfter(target, element) {
  target.insertAdjacentElement("afterend", element);
}

export function remove(e) {
  e.remove();
}

export function map_new() {
  return new Map();
}

export function map_set(map, key, value) {
  return map.set(key, value);
}

export function map_get(map, key) {
  if (map.has(key)) {
    return new Ok(map.get(key));
  }
  return new Error(undefined);
}
export function map_size(map) {
  return map.size;
}

export function array_graphmemes(string) {
  return [...string];
}

// https://stackoverflow.com/questions/1966476/how-can-i-process-each-letter-of-text-using-javascript
export function foldGraphmemes(string, initial, f) {
  let value = initial;
  // for (const ch of string) {
  //   value = f(value, ch);
  // }
  [...string].forEach((c, i) => {
    value = f(value, c, i);
  });
  return value;
}
