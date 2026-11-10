import fixture_eunit_only

pub fn answer_test() {
  case fixture_eunit_only.answer() == 42 {
    True -> Nil
    False -> panic as "answer"
  }
}
