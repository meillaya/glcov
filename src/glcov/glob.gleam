import gleam/list
import gleam/string

/// Small glob matcher for `--exclude`.
///
/// `*` matches any run of characters (including `/`); there is no separate
/// character-class syntax. Examples:
///
///   src/generated/*      matches everything below src/generated/
///   *.generated.gleam    matches that suffix
///   src/foo.gleam        exact path
pub fn matches(pattern: String, path: String) -> Bool {
  case string.contains(pattern, "*") {
    False -> pattern == path
    True -> {
      let ends_with_star = string.ends_with(pattern, "*")
      let parts =
        string.split(pattern, "*")
        |> drop_trailing_empty(ends_with_star)
      match_parts(parts, path, ends_with_star)
    }
  }
}

pub fn matches_any(patterns: List(String), path: String) -> Bool {
  list.any(patterns, fn(pattern) { matches(pattern, path) })
}

fn drop_trailing_empty(
  parts: List(String),
  ends_with_star: Bool,
) -> List(String) {
  case ends_with_star {
    False -> parts
    True ->
      case list.reverse(parts) {
        ["", ..rest] -> list.reverse(rest)
        _ -> parts
      }
  }
}

fn match_parts(
  parts: List(String),
  remainder: String,
  ends_with_star: Bool,
) -> Bool {
  case parts {
    [] -> True
    [first, ..rest] ->
      case string.starts_with(remainder, first) {
        False -> False
        True -> {
          let after =
            string.slice(
              remainder,
              string.length(first),
              string.length(remainder) - string.length(first),
            )
          case rest {
            [] -> ends_with_star
            _ -> match_rest(rest, after, ends_with_star)
          }
        }
      }
  }
}

fn match_rest(
  parts: List(String),
  remainder: String,
  ends_with_star: Bool,
) -> Bool {
  case parts {
    [] -> True
    [only] ->
      case ends_with_star {
        True -> True
        False -> string.ends_with(remainder, only)
      }
    [part, ..rest] ->
      case string.split_once(remainder, part) {
        Ok(#(_, after)) -> match_rest(rest, after, ends_with_star)
        Error(_) -> False
      }
  }
}
