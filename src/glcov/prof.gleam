import glcov/args.{
  type ProfileMode, CallCount, CallTime, SelfTime, format_percent,
}
import glcov/cover.{type SelectedModule}
import glcov/ffi
import gleam/int
import gleam/list
import gleam/string

pub type Row {
  Row(
    source: String,
    line: Int,
    function: String,
    arity: Int,
    calls: Int,
    measurement: Int,
  )
}

pub type Report {
  Report(mode: ProfileMode, total: Int, rows: List(Row), test_status: Int)
}

/// Profile the project's test suite with tprof and map the resulting MFA
/// data back to function definition lines in .gleam sources.
pub fn run(
  modules: List(SelectedModule),
  root: String,
  mode: ProfileMode,
  color: Bool,
) -> Result(Report, String) {
  let mode_string = case mode {
    CallTime -> "call_time"
    CallCount -> "call_count"
    SelfTime -> "self_time"
  }

  case ffi.profile_tests(root, color, mode_string) {
    Error(message) -> Error(message)
    Ok(#(test_status, _all_total, lines)) -> {
      let functions = module_functions(modules)
      let rows =
        lines
        |> list.filter_map(fn(entry) {
          let #(module, function, arity, calls, measurement, _percent) = entry
          case is_reportable(function) {
            False -> Error(Nil)
            True ->
              case
                list.find(functions, fn(candidate) {
                  let #(candidate_module, _, candidate_name, candidate_arity, _) =
                    candidate
                  candidate_module == module
                  && candidate_name == function
                  && candidate_arity == arity
                })
              {
                Error(_) -> Error(Nil)
                Ok(#(_, source, _, _, line)) ->
                  Ok(Row(source, line, function, arity, calls, measurement))
              }
          }
        })
        |> list.sort(by: fn(a, b) { int.compare(b.measurement, a.measurement) })
      let total =
        rows
        |> list.fold(0, fn(total, row) { total + row.measurement })
      Ok(Report(mode, total, rows, test_status))
    }
  }
}

fn is_reportable(function: String) -> Bool {
  !string.starts_with(function, "-") && function != "module_info"
}

fn module_functions(
  modules: List(SelectedModule),
) -> List(#(String, String, String, Int, Int)) {
  modules
  |> list.flat_map(fn(module) {
    ffi.beam_functions(module.beam)
    |> list.map(fn(entry) {
      let #(name, arity, line) = entry
      #(module.module, module.source, name, arity, line)
    })
  })
}

pub fn test_status(report: Report) -> Int {
  report.test_status
}

pub fn has_rows(report: Report) -> Bool {
  !list.is_empty(report.rows)
}

pub fn render(report: Report, top: Int) -> String {
  case report.rows {
    [] -> "No profile data was collected. Does the project have tests?"
    _ -> {
      let rows = list.take(report.rows, top)
      let location_width =
        rows
        |> list.fold(8, fn(width, row) {
          case string.length(location(row)) > width {
            True -> string.length(location(row))
            False -> width
          }
        })
      let function_width =
        rows
        |> list.fold(8, fn(width, row) {
          case string.length(function_label(row)) > width {
            True -> string.length(function_label(row))
            False -> width
          }
        })
      let header =
        pad_right("Location", location_width)
        <> "  "
        <> pad_right("Function", function_width)
        <> "  "
        <> pad_left("Calls", 8)
        <> measurement_header(report.mode)
        <> "  "
        <> pad_left("%", 7)
      let body =
        rows
        |> list.map(fn(row) {
          pad_right(location(row), location_width)
          <> "  "
          <> pad_right(function_label(row), function_width)
          <> "  "
          <> pad_left(int.to_string(row.calls), 8)
          <> measurement_column(report.mode, row)
          <> "  "
          <> pad_left(percent(report, row), 7)
        })
      header <> "\n" <> string.join(body, "\n")
    }
  }
}

pub fn render_summary(report: Report, top: Int) -> String {
  case report.rows {
    [] -> "No profile data was collected."
    _ -> {
      let mode = case report.mode {
        CallTime -> "call_time (inclusive time, us)"
        CallCount -> "call_count"
        SelfTime -> "self_time (own time, us)"
      }
      "Profile: "
      <> mode
      <> ", "
      <> int.to_string(list.length(report.rows))
      <> " function(s) in project code, top "
      <> int.to_string(top)
      <> " shown"
    }
  }
}

fn location(row: Row) -> String {
  row.source <> ":" <> int.to_string(row.line)
}

fn function_label(row: Row) -> String {
  row.function <> "/" <> int.to_string(row.arity)
}

fn measurement_header(mode: ProfileMode) -> String {
  case mode {
    CallTime -> "  " <> pad_left("Time (us)", 13)
    CallCount -> ""
    SelfTime -> "  " <> pad_left("Own (us)", 13)
  }
}

fn measurement_column(mode: ProfileMode, row: Row) -> String {
  case mode {
    CallTime -> "  " <> pad_left(int.to_string(row.measurement), 13)
    CallCount -> ""
    SelfTime -> "  " <> pad_left(int.to_string(row.measurement), 13)
  }
}

fn percent(report: Report, row: Row) -> String {
  case report.total {
    0 -> "0.00"
    _ -> format_percent(row.measurement * 10_000 / report.total)
  }
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
