import fixture_failing
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn classify_positive_test() {
  fixture_failing.classify(1) |> should.equal("WRONG")
}
