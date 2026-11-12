import fixture_js_target
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn classify_zero_test() {
  fixture_js_target.classify(0) |> should.equal("zero")
}
