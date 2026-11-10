import fixture_stateful
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn answer_test() {
  fixture_stateful.answer() |> should.equal(42)
}
