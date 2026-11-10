import glcov/coverage.{
  type FileCoverage, type FunctionCoverage, type Report, file_covered_count,
  line_count,
}
import gleam/int
import gleam/list
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
