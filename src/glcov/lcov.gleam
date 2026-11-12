import glcov/coverage.{
  type FileCoverage, type FunctionCoverage, type Report, file_covered_count,
  line_count,
}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

/// Serialise a coverage report as an lcov.info file.
///
/// Function records are emitted when function data is present. Branch
/// records are absent because Erlang cover does not provide branch data.
pub fn render(report: Report) -> String {
  let records =
    report.files
    |> list.filter(fn(file) { !list.is_empty(file.lines) })
    |> list.map(render_file)
  "TN:\n" <> string.join(records, "")
}

fn render_file(file: FileCoverage) -> String {
  let lines = list.sort(file.lines, by: fn(a, b) { int.compare(a.0, b.0) })
  let covered = file_covered_count(lines)
  let total = line_count(lines)
  let source = normalise_path(file.source)
  let line_records =
    lines
    |> list.map(fn(entry) {
      let #(line, is_covered) = entry
      "DA:" <> int.to_string(line) <> "," <> hit(is_covered) <> "\n"
    })
    |> string.join("")
  let function_records = render_functions(file)
  "SF:"
  <> source
  <> "\n"
  <> function_records
  <> line_records
  <> "LF:"
  <> int.to_string(total)
  <> "\nLH:"
  <> int.to_string(covered)
  <> "\nend_of_record\n"
}

fn render_functions(file: FileCoverage) -> String {
  case file.functions {
    [] -> ""
    functions -> {
      let definitions =
        functions
        |> list.map(fn(function) {
          "FN:"
          <> int.to_string(function.line)
          <> ","
          <> function_label(function)
          <> "\n"
        })
        |> string.join("")
      let hits =
        functions
        |> list.map(fn(function) {
          "FNDA:"
          <> int.to_string(function.calls)
          <> ","
          <> function_label(function)
          <> "\n"
        })
        |> string.join("")
      let found = list.length(functions)
      let hit_count =
        functions
        |> list.filter(fn(function) { function.calls > 0 })
        |> list.length
      definitions
      <> hits
      <> "FNF:"
      <> int.to_string(found)
      <> "\nFNH:"
      <> int.to_string(hit_count)
      <> "\n"
    }
  }
}

fn function_label(function: FunctionCoverage) -> String {
  function.name <> "/" <> int.to_string(function.arity)
}

fn hit(is_covered: Bool) -> String {
  case is_covered {
    True -> "1"
    False -> "0"
  }
}

/// lcov consumers expect forward slashes even on Windows.
pub fn normalise_path(path: String) -> String {
  string.replace(path, "\\", "/")
}

type ParseState {
  ParseState(
    source: Option(String),
    records: List(#(String, List(#(Int, Bool)))),
    error: Option(String),
  )
}

/// Parse the line subset of lcov emitted by c8.
pub fn parse(
  contents: String,
) -> Result(List(#(String, List(#(Int, Bool)))), String) {
  let state =
    string.split(contents, "\n")
    |> list.fold(ParseState(None, [], None), fn(state, line) {
      case state.error {
        Some(_) -> state
        None -> parse_line(state, string.trim(line))
      }
    })

  case state.error {
    Some(message) -> Error(message)
    None -> {
      let records =
        state.records
        |> list.reverse
        |> list.map(fn(record) {
          let #(source, lines) = record
          #(source, list.sort(lines, by: fn(a, b) { int.compare(a.0, b.0) }))
        })
      case records {
        [] -> Error("lcov file contains no source records")
        _ -> Ok(records)
      }
    }
  }
}

fn parse_line(state: ParseState, line: String) -> ParseState {
  case line {
    "" -> state
    _ ->
      case string.starts_with(line, "SF:") {
        True ->
          ParseState(
            source: Some(string.slice(line, 3, string.length(line) - 3)),
            records: state.records,
            error: None,
          )
        False ->
          case string.starts_with(line, "DA:") {
            True ->
              parse_da_line(
                state,
                string.slice(line, 3, string.length(line) - 3),
              )
            False ->
              case line == "end_of_record" {
                True -> finish_record(state)
                False -> state
              }
          }
      }
  }
}

fn parse_da_line(state: ParseState, value: String) -> ParseState {
  case state.source {
    None -> ParseState(..state, error: Some("lcov DA record before SF record"))
    Some(source) ->
      case string.split(value, ",") {
        [line, count, ..] ->
          case int.parse(line) {
            Ok(line_number) ->
              case int.parse(count) {
                Ok(hits) ->
                  ParseState(
                    source: Some(source),
                    records: update_record(state.records, source, #(
                      line_number,
                      hits > 0,
                    )),
                    error: None,
                  )
                Error(_) ->
                  ParseState(
                    ..state,
                    error: Some("lcov contains a malformed DA record"),
                  )
              }
            Error(_) ->
              ParseState(
                ..state,
                error: Some("lcov contains a malformed DA record"),
              )
          }
        _ ->
          ParseState(
            ..state,
            error: Some("lcov contains a malformed DA record"),
          )
      }
  }
}

fn update_record(
  records: List(#(String, List(#(Int, Bool)))),
  source: String,
  line: #(Int, Bool),
) -> List(#(String, List(#(Int, Bool)))) {
  case
    list.find(records, fn(record) {
      let #(candidate, _) = record
      candidate == source
    })
  {
    Ok(#(_, _lines)) ->
      list.map(records, fn(record) {
        let #(candidate, existing) = record
        case candidate == source {
          True -> #(candidate, [line, ..existing])
          False -> record
        }
      })
    Error(_) -> [#(source, [line]), ..records]
  }
}

fn finish_record(state: ParseState) -> ParseState {
  case state.source {
    None -> state
    Some(_) -> ParseState(source: None, records: state.records, error: None)
  }
}
