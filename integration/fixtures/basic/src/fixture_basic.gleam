pub fn classify(n: Int) -> String {
  case n {
    0 -> "zero"
    n if n > 0 -> "positive"
    _ -> "negative"
  }
}

pub fn untested() -> Int {
  1 + 2
}
