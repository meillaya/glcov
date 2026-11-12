import glcov/args
import glcov/coverage
import glcov/glob
import glcov/lcov
import glcov/prof
import glcov/report
import glcov/toml
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn parse_percent_test() {
  args.parse_percent("0") |> should.equal(Ok(0))
  args.parse_percent("80") |> should.equal(Ok(8000))
  args.parse_percent("80.5") |> should.equal(Ok(8050))
  args.parse_percent("80.05") |> should.equal(Ok(8005))
  args.parse_percent("100") |> should.equal(Ok(10_000))
  args.parse_percent("100.00") |> should.equal(Ok(10_000))
  args.parse_percent("100.01")
  |> should.equal(Error("--min must be a percentage between 0 and 100"))
  args.parse_percent("80.005")
  |> should.equal(Error("--min must have at most two decimal places"))
  args.parse_percent("-1")
  |> should.equal(Error("--min must be a percentage between 0 and 100"))
  args.parse_percent("nope")
  |> should.equal(Error("--min must be a percentage between 0 and 100"))
}

pub fn format_percent_test() {
  args.format_percent(8000) |> should.equal("80.00")
  args.format_percent(8050) |> should.equal("80.50")
  args.format_percent(8005) |> should.equal("80.05")
}

pub fn parse_run_options_test() {
  args.parse([
    "run",
    "--min",
    "80.5",
    "--lcov",
    "coverage/out.info",
    "--exclude",
    "src/gen/*",
    "--exclude",
    "src/skip.gleam",
    "--quiet",
    "--no-build",
  ])
  |> should.equal(
    Ok(
      args.Run(args.Options(
        min_bp: Some(8050),
        lcov: Some("coverage/out.info"),
        no_lcov: False,
        excludes: ["src/skip.gleam", "src/gen/*"],
        include_deps: [],
        use_path_deps: True,
        quiet: True,
        no_color: False,
        no_build: True,
        root: None,
        app: None,
        target: args.ErlangTarget,
        verbose: False,
      )),
    ),
  )
}

pub fn parse_profiler_test() {
  args.parse(["prof", "test"])
  |> should.equal(Ok(args.Prof(args.default_prof_options())))

  args.parse([
    "prof",
    "test",
    "--mode",
    "call_count",
    "--top",
    "5",
    "--quiet",
    "--no-build",
  ])
  |> should.equal(
    Ok(
      args.Prof(args.ProfOptions(
        mode: args.CallCount,
        top: 5,
        root: None,
        app: None,
        no_build: True,
        no_color: False,
        quiet: True,
      )),
    ),
  )

  args.parse(["prof", "test", "--mode", "self_time"])
  |> should.equal(
    Ok(
      args.Prof(args.ProfOptions(
        mode: args.SelfTime,
        top: 20,
        root: None,
        app: None,
        no_build: False,
        no_color: False,
        quiet: False,
      )),
    ),
  )

  args.parse(["prof", "test", "--mode", "nope"]) |> should.be_error
  args.parse(["prof", "test", "--top", "0"]) |> should.be_error
  args.parse(["prof"]) |> should.be_error
}

pub fn profile_report_test() {
  let report =
    prof.Report(
      mode: args.CallTime,
      total: 1000,
      rows: [
        prof.Row(
          source: "src/a.gleam",
          line: 3,
          function: "hot",
          arity: 1,
          calls: 10,
          measurement: 900,
        ),
        prof.Row(
          source: "src/a.gleam",
          line: 7,
          function: "cold",
          arity: 0,
          calls: 2,
          measurement: 100,
        ),
      ],
      test_status: 0,
    )

  prof.has_rows(report) |> should.be_true
  prof.test_status(report) |> should.equal(0)
  let rendered = prof.render(report, 20)
  contains(rendered, "src/a.gleam:3") |> should.be_true
  contains(rendered, "hot/1") |> should.be_true
  contains(rendered, "90.00") |> should.be_true
  contains(prof.render_summary(report, 20), "call_time") |> should.be_true

  let empty = prof.Report(args.CallCount, 0, [], 1)
  prof.has_rows(empty) |> should.be_false
  prof.test_status(empty) |> should.equal(1)
}

pub fn parse_help_and_version_test() {
  args.parse([]) |> should.equal(Ok(args.Help))
  args.parse(["--help"]) |> should.equal(Ok(args.Help))
  args.parse(["--version"]) |> should.equal(Ok(args.Version))
  args.parse(["run", "--help"]) |> should.equal(Ok(args.Help))
}

pub fn parse_invalid_test() {
  args.parse(["nope"]) |> should.be_error
  args.parse(["run", "--min"]) |> should.be_error
  args.parse(["run", "--min", "101"]) |> should.be_error
  args.parse(["run", "--wat"]) |> should.be_error
}

pub fn toml_top_level_test() {
  toml.project_name(
    "# comment\nname = \"my_app\"\nversion = \"1.0.0\"\n\n[dependencies]\nname = \"ignored\"\n",
  )
  |> should.equal(Some("my_app"))

  toml.project_name("[dependencies]\nname = \"ignored\"\n")
  |> should.equal(None)

  toml.target("name = \"my_app\"\ntarget = 'javascript'\n")
  |> should.equal(Some("javascript"))
}

pub fn toml_path_dependencies_test() {
  let contents =
    "name = \"app\"\n"
    <> "[dependencies]\n"
    <> "gleam_stdlib = \">= 1.0.0\"\n"
    <> "shared = { path = \"../shared\" }\n"
    <> "\n"
    <> "[dependencies.other]\n"
    <> "path = '../other'\n"
    <> "\n"
    <> "[dev-dependencies]\n"
    <> "tool = { path = \"../tool\" }\n"

  toml.path_dependencies(contents)
  |> should.equal([
    toml.PathDependency("shared", "../shared"),
    toml.PathDependency("other", "../other"),
  ])

  toml.path_dependencies("name = \"app\"\n") |> should.equal([])
}

pub fn parse_target_test() {
  args.parse(["run", "--target", "javascript"])
  |> should.equal(
    Ok(args.Run(
      args.Options(..args.default_options(), target: args.JavascriptTarget),
    )),
  )

  args.parse(["run", "--target", "nope"]) |> should.be_error
}

pub fn javascript_source_maps_test() {
  toml.javascript_source_maps(
    "name = \"app\"\n[javascript]\nsource_maps = true\n",
  )
  |> should.be_true
  toml.javascript_source_maps(
    "name = \"app\"\n[javascript]\nsource_maps = false\n",
  )
  |> should.be_false
  toml.javascript_source_maps("name = \"app\"\n") |> should.be_false
}

pub fn lcov_parse_test() {
  lcov.parse(
    "TN:\n"
    <> "SF:src/a.gleam\n"
    <> "DA:2,1\n"
    <> "DA:3,0\n"
    <> "end_of_record\n",
  )
  |> should.equal(Ok([#("src/a.gleam", [#(2, True), #(3, False)])]))

  lcov.parse("TN:\n") |> should.be_error
}

pub fn glob_test() {
  glob.matches("src/foo.gleam", "src/foo.gleam") |> should.be_true
  glob.matches("src/gen/*", "src/gen/a.gleam") |> should.be_true
  glob.matches("src/gen/*", "src/generate/a.gleam") |> should.be_false
  glob.matches("src/*", "src/generate/a.gleam") |> should.be_true
  glob.matches("*.generated.gleam", "src/a.generated.gleam") |> should.be_true
  glob.matches("src/foo.gleam", "src/bar.gleam") |> should.be_false
  glob.matches_any(["src/gen/*", "src/skip.gleam"], "src/skip.gleam")
  |> should.be_true
}

pub fn coverage_report_test() {
  let sample =
    coverage.from_modules([
      #("a", "src/a.gleam", [#(5, False), #(3, True), #(4, True)]),
      #("b", "src/b.gleam", [#(1, True)]),
    ])

  coverage.total_lines(sample) |> should.equal(4)
  coverage.covered_lines(sample) |> should.equal(3)
  coverage.uncovered_lines(sample) |> should.equal(1)
  coverage.percentage_bp(sample) |> should.equal(7500)
  coverage.percentage_string(sample) |> should.equal("75.00")
  coverage.meets_minimum(sample, 7500) |> should.be_true
  coverage.meets_minimum(sample, 7501) |> should.be_false
}

pub fn coverage_empty_test() {
  let empty = coverage.from_modules([])
  coverage.total_lines(empty) |> should.equal(0)
  coverage.percentage_bp(empty) |> should.equal(0)
  coverage.meets_minimum(empty, 0) |> should.be_false
}

pub fn lcov_test() {
  let sample =
    coverage.from_modules([
      #("a", "src/a.gleam", [#(5, False), #(3, True)]),
    ])

  lcov.render(sample)
  |> should.equal(
    "TN:\n"
    <> "SF:src/a.gleam\n"
    <> "DA:3,1\n"
    <> "DA:5,0\n"
    <> "LF:2\n"
    <> "LH:1\n"
    <> "end_of_record\n",
  )
}

pub fn function_coverage_test() {
  let sample =
    coverage.from_modules_with_functions(
      [#("a", "src/a.gleam", [#(2, True), #(5, False)])],
      [
        #("src/a.gleam", "classify", 1, 1, 2),
        #("src/a.gleam", "unused", 5, 0, 0),
      ],
    )

  coverage.total_functions(sample) |> should.equal(2)
  coverage.covered_functions(sample) |> should.equal(1)
  lcov.render(sample)
  |> should.equal(
    "TN:\n"
    <> "SF:src/a.gleam\n"
    <> "FN:1,classify/1\n"
    <> "FN:5,unused/0\n"
    <> "FNDA:2,classify/1\n"
    <> "FNDA:0,unused/0\n"
    <> "FNF:2\n"
    <> "FNH:1\n"
    <> "DA:2,1\n"
    <> "DA:5,0\n"
    <> "LF:2\n"
    <> "LH:1\n"
    <> "end_of_record\n",
  )
}

pub fn lcov_windows_paths_test() {
  lcov.render(coverage.from_modules([#("a", "src\\a.gleam", [#(1, True)])]))
  |> should.equal("TN:\nSF:src/a.gleam\nDA:1,1\nLF:1\nLH:1\nend_of_record\n")
}

pub fn table_test() {
  let sample =
    coverage.from_modules([
      #("a", "src/a.gleam", [#(1, True), #(2, False)]),
    ])
  let rendered = report.render(sample)
  #(
    contains(rendered, "File"),
    contains(rendered, "src/a.gleam"),
    contains(rendered, "TOTAL"),
    contains(rendered, "50.00"),
  )
  |> should.equal(#(True, True, True, True))

  contains(
    report.render_summary(sample),
    "Coverage: 50.00% (1/2 lines covered)",
  )
  |> should.be_true
}

fn contains(haystack: String, needle: String) -> Bool {
  string.contains(haystack, needle)
}
