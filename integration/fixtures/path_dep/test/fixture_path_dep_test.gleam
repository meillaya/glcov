import fixture_path_dep
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn compute_test() {
  fixture_path_dep.compute(1) |> should.equal(2)
}
