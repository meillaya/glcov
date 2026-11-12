import glcov/ffi
import glcov/toml
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Project {
  Project(root: String, name: String, target: String)
}

pub fn locate(root_override: Option(String)) -> Result(Project, String) {
  let root = case root_override {
    Some(value) -> absolute_path(value)
    None -> ffi.find_project_root()
  }
  case root {
    "" -> Error("No gleam.toml found. Run glcov from inside a Gleam project.")
    _ -> {
      let config_path = join(root, "gleam.toml")
      case ffi.read_file(config_path) {
        Error(message) -> Error("Could not read gleam.toml: " <> message)
        Ok(contents) ->
          case toml.project_name(contents) {
            None -> Error("gleam.toml has no top-level `name` field.")
            Some(name) -> {
              let target = option_default(toml.target(contents), "erlang")
              Ok(Project(root, name, target))
            }
          }
      }
    }
  }
}

fn absolute_path(path: String) -> String {
  case is_absolute_path(path) {
    True -> path
    False -> join(ffi.get_cwd(), path)
  }
}

/// Resolve a project-relative path against the project root.
pub fn resolve_path(project: Project, path: String) -> String {
  case is_absolute_path(path) {
    True -> path
    False -> join(project.root, path)
  }
}

pub fn path_dependencies(
  project: Project,
) -> Result(List(toml.PathDependency), String) {
  case ffi.read_file(join(project.root, "gleam.toml")) {
    Error(message) -> Error("Could not read gleam.toml: " <> message)
    Ok(contents) -> Ok(toml.path_dependencies(contents))
  }
}

pub fn is_absolute_path(path: String) -> Bool {
  string.starts_with(path, "/")
  || string.starts_with(path, "\\")
  || case string.length(path) >= 3 {
    True ->
      string.slice(path, 1, 1) == ":"
      && { string.slice(path, 2, 1) == "/" || string.slice(path, 2, 1) == "\\" }
    False -> False
  }
}

/// Check that the tools needed to build and analyse the project exist.
pub fn check_toolchain(project: Project) -> Result(Nil, String) {
  let gleam = case ffi.which("gleam") {
    Error(message) ->
      Error("Could not find the `gleam` executable: " <> message)
    Ok(path) -> Ok(path)
  }
  case gleam {
    Error(message) -> Error(message)
    Ok(gleam_path) -> {
      let version = case ffi.capture(gleam_path, ["--version"], project.root) {
        #(0, output) -> parse_gleam_version(output)
        #(_, output) ->
          Error(
            "Could not determine the Gleam version: " <> string.trim(output),
          )
      }
      case version {
        Error(message) -> Error(message)
        Ok(acceptable) ->
          case acceptable {
            False ->
              Error(
                "glcov requires Gleam 1.19.0 or newer for source line metadata.",
              )
            True -> {
              let otp = ffi.otp_release()
              case int.parse(otp) {
                Ok(release) if release >= 26 -> Ok(Nil)
                _ ->
                  Error(
                    "glcov requires Erlang/OTP 26 or newer (found OTP "
                    <> otp
                    <> ").",
                  )
              }
            }
          }
      }
    }
  }
}

/// Build the project for the Erlang target. This compiles src, test, dev,
/// and dev dependencies; it deliberately does not run `gleam test`.
pub fn build(project: Project) -> Result(Nil, String) {
  build_target(project, "erlang")
}

pub fn build_target(project: Project, target: String) -> Result(Nil, String) {
  case ffi.which("gleam") {
    Error(message) ->
      Error("Could not find the `gleam` executable: " <> message)
    Ok(gleam) ->
      case ffi.run(gleam, ["build", "--target", target], project.root) {
        0 -> Ok(Nil)
        status ->
          Error(
            "`gleam build --target "
            <> target
            <> "` failed with exit code "
            <> int.to_string(status)
            <> ".",
          )
      }
  }
}

pub fn js_build_dir(project: Project) -> String {
  join(project.root, "build/dev/javascript/" <> project.name)
}

pub fn javascript_source_maps(project: Project) -> Result(Bool, String) {
  case ffi.read_file(join(project.root, "gleam.toml")) {
    Error(message) -> Error("Could not read gleam.toml: " <> message)
    Ok(contents) -> Ok(toml.javascript_source_maps(contents))
  }
}

pub fn ebin(project: Project, app: String) -> String {
  join(project.root, "build/dev/erlang/" <> app <> "/ebin")
}

pub fn app_name(project: Project, override: Option(String)) -> String {
  case override {
    Some(value) -> value
    None -> project.name
  }
}

/// Is the project configured for a target other than Erlang by default?
/// The CLI can still be invoked with `gleam run --target erlang`; this is
/// only used for a helpful diagnostic.
pub fn default_target_is_javascript(project: Project) -> Bool {
  project.target == "javascript"
}

fn parse_gleam_version(output: String) -> Result(Bool, String) {
  let tokens = string.split(output, " ")
  case first_version_token(tokens) {
    None -> Error("Unexpected `gleam --version` output: " <> output)
    Some(version) -> {
      let parts = string.split(string.trim(version), ".")
      case parts {
        [major, minor, ..] ->
          case int.parse(major), int.parse(minor) {
            Ok(major_number), Ok(minor_number) ->
              Ok(
                major_number > 1 || { major_number == 1 && minor_number >= 19 },
              )
            _, _ -> Error("Unexpected Gleam version: " <> version)
          }
        _ -> Error("Unexpected Gleam version: " <> version)
      }
    }
  }
}

fn first_version_token(tokens: List(String)) -> Option(String) {
  case
    list.find_map(tokens, fn(token) {
      let trimmed = string.trim(token)
      case string.length(trimmed) > 0 && is_digit(string.slice(trimmed, 0, 1)) {
        True -> Ok(trimmed)
        False -> Error(Nil)
      }
    })
  {
    Ok(token) -> Some(token)
    Error(_) -> None
  }
}

fn is_digit(character: String) -> Bool {
  string.contains("0123456789", character)
}

fn option_default(value: Option(String), default: String) -> String {
  case value {
    Some(value) -> value
    None -> default
  }
}

fn join(left: String, right: String) -> String {
  case string.ends_with(left, "/") {
    True -> left <> right
    False -> left <> "/" <> right
  }
}
