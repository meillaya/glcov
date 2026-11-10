import fixture_basic
import gleeunit
import gleeunit/should

@external(erlang, "persistent_term", "get")
fn get(key: String, default: Bool) -> Bool

pub fn main() {
  gleeunit.main()
}

pub fn classify_positive_test() {
  fixture_basic.classify(1) |> should.equal("positive")
}

pub fn classify_zero_test() {
  fixture_basic.classify(0) |> should.equal("zero")
}

pub fn setup_hook_test() {
  get("glcov_setup_ready", False) |> should.equal(True)
}
