import glcov/cli
import glcov/ffi

/// Entry point for `gleam run -m glcov`.
pub fn main() -> Nil {
  case ffi.is_erlang() {
    True -> cli.main(ffi.plain_args())
    False -> {
      let _ =
        ffi.eprintln(
          "glcov: only the Erlang target is supported. Run the project's tests "
          <> "on the Erlang target to collect coverage.",
        )
      ffi.halt(2)
    }
  }
}

/// Entry point used by the standalone escript (and testable without the
/// `-extra` argument plumbing).
pub fn main_with_args(arguments: List(String)) -> Nil {
  cli.main(arguments)
}

/// Entry point used by the standalone escript. Unlike `gleam run -m glcov`,
/// the escript is not launched by `<app>@@main`, so it starts the project
/// application itself after cover instrumentation.
pub fn main_escript(arguments: List(String)) -> Nil {
  cli.main_escript(arguments)
}
