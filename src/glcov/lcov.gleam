import glcov/coverage.{
  type FileCoverage, type Report, file_covered_count, line_count,
}
import gleam/int
import gleam/list
import gleam/string

/// Serialise a coverage report as a line-coverage lcov.info file.
///
/// Branch and function records are intentionally absent in 0.2.0: Erlang
/// cover gives line counts only, and inventing branch data would be worse
/// than omitting it.
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
  "SF:"
  <> source
  <> "\n"
  <> line_records
  <> "LF:"
  <> int.to_string(total)
  <> "\nLH:"
  <> int.to_string(covered)
  <> "\nend_of_record\n"
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
