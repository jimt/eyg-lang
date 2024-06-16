import lustre/effect

pub fn init(_) {
  #(5, effect.none())
}

pub fn update(state, message) {
  #(state, effect.none())
}
