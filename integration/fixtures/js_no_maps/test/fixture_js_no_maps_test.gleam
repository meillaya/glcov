import fixture_js_no_maps
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn value_test() {
  fixture_js_no_maps.value() |> should.equal(1)
}
