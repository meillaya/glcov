import glcov/args
import gleam/int
import gleam/list
import gleam/string

pub type FunctionCoverage {
  FunctionCoverage(name: String, arity: Int, line: Int, calls: Int)
}

pub type FileCoverage {
  FileCoverage(
    module: String,
    source: String,
    lines: List(#(Int, Bool)),
    functions: List(FunctionCoverage),
  )
}

pub type Report {
  Report(files: List(FileCoverage))
}

/// Build a report from `{module, source, [{line, covered}]}` entries.
///
/// Sources are already relative to the project root by the time they reach
/// this function; empty sources are dropped and all other files are sorted
/// for deterministic output.
pub fn from_modules(
  modules: List(#(String, String, List(#(Int, Bool)))),
) -> Report {
  from_modules_with_functions(modules, [])
}

/// Build a report with line and function coverage.
///
/// Function rows are `{source, name, line, arity, calls}`.
pub fn from_modules_with_functions(
  modules: List(#(String, String, List(#(Int, Bool)))),
  function_rows: List(#(String, String, Int, Int, Int)),
) -> Report {
  Report(
    files: modules
    |> list.filter_map(fn(entry) {
      let #(module, source, lines) = entry
      case source {
        "" -> Error(Nil)
        _ ->
          Ok(FileCoverage(
            module,
            source,
            list.sort(lines, by: fn(a, b) { int.compare(a.0, b.0) }),
            functions_for_source(function_rows, source),
          ))
      }
    })
    |> list.sort(by: fn(a, b) { string.compare(a.source, b.source) }),
  )
}

fn functions_for_source(
  rows: List(#(String, String, Int, Int, Int)),
  source: String,
) -> List(FunctionCoverage) {
  rows
  |> list.filter_map(fn(entry) {
    let #(row_source, name, line, arity, calls) = entry
    case row_source == source {
      True -> Ok(FunctionCoverage(name, arity, line, calls))
      False -> Error(Nil)
    }
  })
  |> list.sort(by: fn(a, b) { int.compare(a.line, b.line) })
}

pub fn total_functions(report: Report) -> Int {
  report.files
  |> list.fold(0, fn(total, file) { total + list.length(file.functions) })
}

pub fn covered_functions(report: Report) -> Int {
  report.files
  |> list.fold(0, fn(total, file) {
    total
    + list.length(
      list.filter(file.functions, fn(function) { function.calls > 0 }),
    )
  })
}

pub fn total_lines(report: Report) -> Int {
  report.files
  |> list.fold(0, fn(total, file) { total + list.length(file.lines) })
}

pub fn covered_lines(report: Report) -> Int {
  report.files
  |> list.fold(0, fn(total, file) { total + count_covered(file.lines) })
}

fn count_covered(lines: List(#(Int, Bool))) -> Int {
  lines
  |> list.filter(fn(entry) {
    let #(_, covered) = entry
    covered
  })
  |> list.length
}

pub fn uncovered_lines(report: Report) -> Int {
  total_lines(report) - covered_lines(report)
}

/// Total coverage in basis points, rounded down. 0 when there is no data.
pub fn percentage_bp(report: Report) -> Int {
  let total = total_lines(report)
  case total {
    0 -> 0
    _ -> covered_lines(report) * 10_000 / total
  }
}

/// Exact comparison, independent of floating point rounding.
pub fn meets_minimum(report: Report, min_bp: Int) -> Bool {
  let total = total_lines(report)
  total > 0 && covered_lines(report) * 10_000 >= min_bp * total
}

pub fn percentage_string(report: Report) -> String {
  args.format_percent(percentage_bp(report))
}

pub fn file_percentage_bp(lines: List(#(Int, Bool))) -> Int {
  let total = list.length(lines)
  case total {
    0 -> 0
    _ -> count_covered(lines) * 10_000 / total
  }
}

pub fn file_percentage_string(lines: List(#(Int, Bool))) -> String {
  args.format_percent(file_percentage_bp(lines))
}

pub fn line_count(lines: List(#(Int, Bool))) -> Int {
  list.length(lines)
}

pub fn file_covered_count(lines: List(#(Int, Bool))) -> Int {
  count_covered(lines)
}

pub fn format_counts(covered: Int, total: Int) -> String {
  int.to_string(covered) <> "/" <> int.to_string(total)
}

pub fn from_source_lines(
  sources: List(#(String, List(#(Int, Bool)))),
) -> Report {
  Report(
    files: sources
    |> list.filter_map(fn(entry) {
      let #(source, lines) = entry
      case source {
        "" -> Error(Nil)
        _ ->
          Ok(
            FileCoverage(
              source,
              source,
              list.sort(lines, by: fn(a, b) { int.compare(a.0, b.0) }),
              [],
            ),
          )
      }
    })
    |> list.sort(by: fn(a, b) { string.compare(a.source, b.source) }),
  )
}
