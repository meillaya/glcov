import glcov/args
import glcov/coverage.{
  type Report, covered_lines, format_counts, percentage_string, total_lines,
  uncovered_lines,
}
import gleam/int
import gleam/list
import gleam/string

pub fn render(report: Report) -> String {
  let width = source_width(report)
  let header =
    pad_right("File", width)
    <> "  "
    <> pad_left("Lines", 7)
    <> "  "
    <> pad_left("Covered", 8)
    <> "  "
    <> pad_left("Uncovered", 10)
    <> "  "
    <> pad_left("%", 7)
  let rows =
    report.files
    |> list.map(fn(file) {
      let lines = list.length(file.lines)
      let covered = file_covered(file.lines)
      let uncovered = lines - covered
      pad_right(file.source, width)
      <> "  "
      <> pad_left(int.to_string(lines), 7)
      <> "  "
      <> pad_left(int.to_string(covered), 8)
      <> "  "
      <> pad_left(int.to_string(uncovered), 10)
      <> "  "
      <> pad_left(file_percentage(file.lines), 7)
    })
  let total =
    pad_right("TOTAL", width)
    <> "  "
    <> pad_left(int.to_string(total_lines(report)), 7)
    <> "  "
    <> pad_left(int.to_string(covered_lines(report)), 8)
    <> "  "
    <> pad_left(int.to_string(uncovered_lines(report)), 10)
    <> "  "
    <> pad_left(percentage_string(report), 7)
  string.join(list.append([header, ..rows], [total]), "\n")
}

pub fn render_summary(report: Report) -> String {
  "Coverage: "
  <> percentage_string(report)
  <> "% ("
  <> format_counts(covered_lines(report), total_lines(report))
  <> " lines covered)"
}

fn file_covered(lines: List(#(Int, Bool))) -> Int {
  lines
  |> list.filter(fn(entry) {
    let #(_, covered) = entry
    covered
  })
  |> list.length
}

fn file_percentage(lines: List(#(Int, Bool))) -> String {
  let covered = file_covered(lines)
  let total = list.length(lines)
  case total {
    0 -> "0.00"
    _ -> args.format_percent(covered * 10_000 / total)
  }
}

fn source_width(report: Report) -> Int {
  report.files
  |> list.fold(4, fn(width, file) {
    case string.length(file.source) > width {
      True -> string.length(file.source)
      False -> width
    }
  })
}

fn pad_right(value: String, width: Int) -> String {
  let length = string.length(value)
  case length >= width {
    True -> value
    False -> value <> string.repeat(" ", width - length)
  }
}

fn pad_left(value: String, width: Int) -> String {
  let length = string.length(value)
  case length >= width {
    True -> value
    False -> string.repeat(" ", width - length) <> value
  }
}
