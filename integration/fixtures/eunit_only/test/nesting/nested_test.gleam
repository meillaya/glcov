import fixture_eunit_only

pub fn nested_answer_test() {
  case fixture_eunit_only.nested_only() == 7 {
    True -> Nil
    False -> panic as "nested answer"
  }
}
