// glcov is an Erlang-target tool. These implementations exist so a project
// that tests both targets can still compile glcov as a dev dependency; any
// actual use on the JavaScript target reports the limitation clearly.

function unsupported(name) {
  throw new Error(`glcov: ${name} is only supported on the Erlang target`);
}

export function plain_args() {
  return [];
}

export function is_erlang() {
  return false;
}

export function halt(code) {
  if (typeof process !== "undefined" && typeof process.exit === "function") {
    process.exit(code);
  }
  throw new Error(`glcov: halting with ${code} is not supported here`);
}

export function eprintln(message) {
  if (typeof console !== "undefined") {
    console.error(String(message));
  }
}

export function get_cwd() { unsupported("get_cwd"); }
export function set_cwd(_path) { unsupported("set_cwd"); }
export function find_project_root() { unsupported("find_project_root"); }
export function read_file(_path) { unsupported("read_file"); }
export function file_exists(_path) { unsupported("file_exists"); }
export function is_dir(_path) { unsupported("is_dir"); }
export function write_file(_path, _contents) { unsupported("write_file"); }
export function which(_program) { unsupported("which"); }
export function ensure_app_started(_app) { unsupported("ensure_app_started"); }
export function run(_program, _arguments, _cwd) { unsupported("run"); }
export function capture(_program, _arguments, _cwd) { unsupported("capture"); }
export function otp_release() { unsupported("otp_release"); }
export function add_code_paths(_paths) { unsupported("add_code_paths"); }
export function find_ebins(_root) { unsupported("find_ebins"); }
export function beam_sources(_ebin) { unsupported("beam_sources"); }
export function beam_functions(_beam) { unsupported("beam_functions"); }
export function profile_tests(_root, _color, _mode) { unsupported("profile_tests"); }
export function cover_start() { unsupported("cover_start"); }
export function cover_compile(_beam_paths) { unsupported("cover_compile"); }
export function cover_analyse(_modules) { unsupported("cover_analyse"); }
export function cover_analyse_functions(_modules) { unsupported("cover_analyse_functions"); }
export function cover_stop() { unsupported("cover_stop"); }
export function run_tests(_root, _color) { unsupported("run_tests"); }
