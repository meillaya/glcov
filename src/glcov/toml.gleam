import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// A deliberately small reader for the two top-level values glcov needs.
///
/// It only looks before the first table header, which is where `name` and
/// `target` live in a normal `gleam.toml`. A full TOML parser would add a
/// dependency for no benefit here.
pub fn top_level_value(contents: String, key: String) -> Option(String) {
  contents
  |> string.split("\n")
  |> list.take_while(fn(line) { !string.starts_with(string.trim(line), "[") })
  |> list.filter_map(fn(line) { parse_key_value(line, key) })
  |> first_option
}

fn first_option(values: List(String)) -> Option(String) {
  case list.first(values) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

fn parse_key_value(line: String, key: String) -> Result(String, Nil) {
  let trimmed = string.trim(line)
  case trimmed {
    "" -> Error(Nil)
    _ ->
      case string.starts_with(trimmed, "#") {
        True -> Error(Nil)
        False ->
          case string.split(trimmed, "=") {
            [left, right, ..rest] -> {
              let found_key = string.trim(left)
              case found_key == key {
                True -> Ok(clean_value(string.join([right, ..rest], "=")))
                False -> Error(Nil)
              }
            }
            _ -> Error(Nil)
          }
      }
  }
}

fn clean_value(value: String) -> String {
  let trimmed = string.trim(value)
  let without_comment = case string.split(trimmed, "#") {
    [value, ..] -> string.trim(value)
    [] -> trimmed
  }
  case string.length(without_comment) >= 2 {
    True -> {
      let first = string.slice(without_comment, 0, 1)
      let last =
        string.slice(without_comment, string.length(without_comment) - 1, 1)
      case first, last {
        "\"", "\"" ->
          string.slice(without_comment, 1, string.length(without_comment) - 2)
        "'", "'" ->
          string.slice(without_comment, 1, string.length(without_comment) - 2)
        _, _ -> without_comment
      }
    }
    False -> without_comment
  }
}

pub fn project_name(contents: String) -> Option(String) {
  top_level_value(contents, "name")
}

pub fn target(contents: String) -> Option(String) {
  top_level_value(contents, "target")
}

pub type PathDependency {
  PathDependency(name: String, path: String)
}

/// Direct runtime path dependencies from `[dependencies]`.
///
/// Only direct dependencies are returned. Development dependencies are
/// intentionally skipped because tools such as glcov are commonly declared
/// there as path dependencies and should not enter project coverage.
pub fn path_dependencies(contents: String) -> List(PathDependency) {
  let lines = string.split(contents, "\n")
  let #(_, found) =
    list.fold(lines, #(TopLevel, []), fn(state, line) {
      let #(section, found) = state
      let trimmed = string.trim(line)
      case is_section_header(trimmed) {
        True -> #(parse_section(trimmed), found)
        False ->
          case section {
            InDependencies ->
              case parse_inline_dependency(trimmed) {
                Some(dependency) -> #(section, [dependency, ..found])
                None -> #(section, found)
              }
            InDependency(name) ->
              case parse_subtable_path(trimmed) {
                Some(path) -> #(section, [PathDependency(name, path), ..found])
                None -> #(section, found)
              }
            _ -> #(section, found)
          }
      }
    })
  list.reverse(found)
}

type Section {
  TopLevel
  InDependencies
  InDependency(name: String)
  Ignored
}

fn is_section_header(line: String) -> Bool {
  string.starts_with(line, "[") && string.ends_with(line, "]")
}

fn parse_section(line: String) -> Section {
  case string.slice(line, 1, string.length(line) - 2) {
    "dependencies" -> InDependencies
    header ->
      case string.split(header, ".") {
        ["dependencies", name, ..] -> InDependency(name)
        _ -> Ignored
      }
  }
}

fn parse_inline_dependency(line: String) -> Option(PathDependency) {
  case string.split(line, "=") {
    [name, value, ..rest] -> {
      let value = string.join([value, ..rest], "=")
      case extract_path(value) {
        Some(path) -> Some(PathDependency(string.trim(name), path))
        None -> None
      }
    }
    _ -> None
  }
}

fn parse_subtable_path(line: String) -> Option(String) {
  case string.split(line, "=") {
    [key, value, ..] ->
      case string.trim(key) == "path" {
        True -> quoted_value(value)
        False -> None
      }
    _ -> None
  }
}

fn extract_path(value: String) -> Option(String) {
  case string.split(value, "path") {
    [_, after_path, ..rest] -> {
      let after_path = string.join([after_path, ..rest], "path")
      case string.split(after_path, "=") {
        [_, raw, ..rest] -> quoted_value(string.join([raw, ..rest], "="))
        _ -> None
      }
    }
    _ -> None
  }
}

fn quoted_value(value: String) -> Option(String) {
  let trimmed = string.trim(value)
  let double = string.split(trimmed, "\"")
  let single = string.split(trimmed, "'")
  case double, single {
    [_, path, ..], _ -> Some(path)
    _, [_, path, ..] -> Some(path)
    _, _ -> None
  }
}

/// Whether `[javascript] source_maps` is enabled.
pub fn javascript_source_maps(contents: String) -> Bool {
  let lines = string.split(contents, "\n")
  let #(_, enabled) =
    list.fold(lines, #(False, False), fn(state, line) {
      let #(in_javascript, enabled) = state
      let trimmed = string.trim(line)
      case is_section_header(trimmed) {
        True -> #(parse_section_name(trimmed) == "javascript", enabled)
        False ->
          case in_javascript {
            False -> #(False, enabled)
            True ->
              case string.split(trimmed, "=") {
                [key, value, ..rest] ->
                  case string.trim(key) == "source_maps" {
                    True -> {
                      let value = clean_value(string.join([value, ..rest], "="))
                      #(True, value == "true")
                    }
                    False -> #(True, enabled)
                  }
                _ -> #(True, enabled)
              }
          }
      }
    })
  enabled
}

fn parse_section_name(line: String) -> String {
  string.slice(line, 1, string.length(line) - 2)
}
