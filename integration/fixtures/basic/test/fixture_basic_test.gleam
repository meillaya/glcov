import fixture_basic
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn classify_positive_test() {
  fixture_basic.classify(1) |> should.equal("positive")
}

pub fn classify_zero_test() {
  fixture_basic.classify(0) |> should.equal("zero")
}
