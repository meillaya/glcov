//// The small Erlang interface used by glcov.
////
//// Everything here is exercised through the CLI, but keeping it in one
//// module makes the boundary easy to audit.

@external(erlang, "glcov_ffi", "plain_args")
@external(javascript, "./glcov_ffi.mjs", "plain_args")
pub fn plain_args() -> List(String)

@external(erlang, "glcov_ffi", "is_erlang")
@external(javascript, "./glcov_ffi.mjs", "is_erlang")
pub fn is_erlang() -> Bool

@external(erlang, "glcov_ffi", "halt")
@external(javascript, "./glcov_ffi.mjs", "halt")
pub fn halt(code: Int) -> Nil

@external(erlang, "glcov_ffi", "eprintln")
@external(javascript, "./glcov_ffi.mjs", "eprintln")
pub fn eprintln(message: String) -> Nil

@external(erlang, "glcov_ffi", "get_cwd")
@external(javascript, "./glcov_ffi.mjs", "get_cwd")
pub fn get_cwd() -> String

@external(erlang, "glcov_ffi", "set_cwd")
@external(javascript, "./glcov_ffi.mjs", "set_cwd")
pub fn set_cwd(path: String) -> Result(Nil, String)

@external(erlang, "glcov_ffi", "find_project_root")
@external(javascript, "./glcov_ffi.mjs", "find_project_root")
pub fn find_project_root() -> String

@external(erlang, "glcov_ffi", "read_file")
@external(javascript, "./glcov_ffi.mjs", "read_file")
pub fn read_file(path: String) -> Result(String, String)

@external(erlang, "glcov_ffi", "file_exists")
@external(javascript, "./glcov_ffi.mjs", "file_exists")
pub fn file_exists(path: String) -> Bool

@external(erlang, "glcov_ffi", "delete_file")
@external(javascript, "./glcov_ffi.mjs", "delete_file")
pub fn delete_file(path: String) -> Nil

@external(erlang, "glcov_ffi", "is_dir")
@external(javascript, "./glcov_ffi.mjs", "is_dir")
pub fn is_dir(path: String) -> Bool

@external(erlang, "glcov_ffi", "write_file")
@external(javascript, "./glcov_ffi.mjs", "write_file")
pub fn write_file(path: String, contents: String) -> Result(Nil, String)

@external(erlang, "glcov_ffi", "which")
@external(javascript, "./glcov_ffi.mjs", "which")
pub fn which(program: String) -> Result(String, String)

@external(erlang, "glcov_ffi", "ensure_app_started")
@external(javascript, "./glcov_ffi.mjs", "ensure_app_started")
pub fn ensure_app_started(app: String) -> Result(Nil, String)

@external(erlang, "glcov_ffi", "run")
@external(javascript, "./glcov_ffi.mjs", "run")
pub fn run(program: String, arguments: List(String), cwd: String) -> Int

@external(erlang, "glcov_ffi", "capture")
@external(javascript, "./glcov_ffi.mjs", "capture")
pub fn capture(
  program: String,
  arguments: List(String),
  cwd: String,
) -> #(Int, String)

@external(erlang, "glcov_ffi", "otp_release")
@external(javascript, "./glcov_ffi.mjs", "otp_release")
pub fn otp_release() -> String

@external(erlang, "glcov_ffi", "add_code_paths")
@external(javascript, "./glcov_ffi.mjs", "add_code_paths")
pub fn add_code_paths(paths: List(String)) -> Nil

@external(erlang, "glcov_ffi", "find_ebins")
@external(javascript, "./glcov_ffi.mjs", "find_ebins")
pub fn find_ebins(root: String) -> List(String)

@external(erlang, "glcov_ffi", "beam_sources")
@external(javascript, "./glcov_ffi.mjs", "beam_sources")
pub fn beam_sources(ebin: String) -> List(#(String, String, String))

@external(erlang, "glcov_ffi", "beam_functions")
@external(javascript, "./glcov_ffi.mjs", "beam_functions")
pub fn beam_functions(beam: String) -> List(#(String, Int, Int))

@external(erlang, "glcov_ffi", "profile_tests")
@external(javascript, "./glcov_ffi.mjs", "profile_tests")
pub fn profile_tests(
  root: String,
  color: Bool,
  mode: String,
) -> Result(#(Int, Int, List(#(String, String, Int, Int, Int, Int))), String)

@external(erlang, "glcov_ffi", "cover_start")
@external(javascript, "./glcov_ffi.mjs", "cover_start")
pub fn cover_start() -> Result(Nil, String)

@external(erlang, "glcov_ffi", "cover_compile")
@external(javascript, "./glcov_ffi.mjs", "cover_compile")
pub fn cover_compile(beam_paths: List(String)) -> List(#(String, String))

@external(erlang, "glcov_ffi", "cover_analyse")
@external(javascript, "./glcov_ffi.mjs", "cover_analyse")
pub fn cover_analyse(
  modules: List(String),
) -> Result(List(#(String, List(#(Int, Bool)))), String)

@external(erlang, "glcov_ffi", "cover_analyse_functions")
@external(javascript, "./glcov_ffi.mjs", "cover_analyse_functions")
pub fn cover_analyse_functions(
  modules: List(String),
) -> Result(List(#(String, List(#(String, Int, Int)))), String)

@external(erlang, "glcov_ffi", "cover_stop")
@external(javascript, "./glcov_ffi.mjs", "cover_stop")
pub fn cover_stop() -> Nil

@external(erlang, "glcov_ffi", "run_tests")
@external(javascript, "./glcov_ffi.mjs", "run_tests")
pub fn run_tests(root: String, color: Bool) -> Int
