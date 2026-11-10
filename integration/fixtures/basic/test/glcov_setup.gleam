@external(erlang, "persistent_term", "put")
fn put(key: String, value: Bool) -> Nil

pub fn setup() -> Nil {
  put("glcov_setup_ready", True)
}
