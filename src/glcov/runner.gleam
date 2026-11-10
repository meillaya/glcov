import glcov/ffi

/// Run the project's EUnit tests with gleeunit's runner when it is
/// available. Returns 0 for success, 1 for test failures, 2 for a runner
/// error.
pub fn run(root: String, color: Bool) -> Int {
  ffi.run_tests(root, color)
}
