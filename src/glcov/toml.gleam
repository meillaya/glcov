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
