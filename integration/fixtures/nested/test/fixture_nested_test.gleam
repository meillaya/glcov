import fixture_nested
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn answer_test() {
  fixture_nested.answer() |> should.equal(3)
}
