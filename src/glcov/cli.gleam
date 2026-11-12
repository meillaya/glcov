import glcov/args
import glcov/cover
import glcov/coverage
import glcov/ffi
import glcov/glob
import glcov/lcov
import glcov/prof
import glcov/project
import glcov/report
import glcov/runner
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string

pub const version: String = "0.4.0"

pub fn main(argv: List(String)) -> Nil {
  main_with_mode(argv, False)
}

pub fn main_escript(argv: List(String)) -> Nil {
  main_with_mode(argv, True)
}

fn main_with_mode(argv: List(String), start_app: Bool) -> Nil {
  case args.parse(argv) {
    Error(message) -> fail(message)
    Ok(args.Help) -> {
      io.println(help_text())
      ffi.halt(0)
    }
    Ok(args.Version) -> {
      io.println("glcov " <> version)
      ffi.halt(0)
    }
    Ok(args.Run(options)) -> run(options, start_app)
    Ok(args.Prof(prof_options)) -> prof_command(prof_options, start_app)
  }
}

fn run(options: args.Options, start_app: Bool) -> Nil {
  case project.locate(options.root) {
    Error(message) -> fail(message)
    Ok(project) -> {
      case ffi.set_cwd(project.root) {
        Error(message) ->
          fail("Could not enter the project directory: " <> message)
        Ok(_) -> run_in_project(project, options, start_app)
      }
    }
  }
}

fn run_in_project(
  project: project.Project,
  options: args.Options,
  start_app: Bool,
) -> Nil {
  case options.target {
    args.ErlangTarget -> run_erlang_in_project(project, options, start_app)
    args.JavascriptTarget -> run_javascript(project, options)
  }
}

fn run_erlang_in_project(
  project: project.Project,
  options: args.Options,
  start_app: Bool,
) -> Nil {
  case project.check_toolchain(project) {
    Error(message) -> fail(message)
    Ok(_) -> {
      let app = project.app_name(project, options.app)
      let ebin = project.ebin(project, app)

      case build_if_needed(project, options.no_build, ebin) {
        Error(message) -> fail(message)
        Ok(_) -> {
          case add_code_paths(project) {
            Error(message) -> fail(message)
            Ok(_) -> run_with_paths(project, options, app, ebin, start_app)
          }
        }
      }
    }
  }
}

fn run_javascript(project: project.Project, options: args.Options) -> Nil {
  case project.check_toolchain(project) {
    Error(message) -> fail(message)
    Ok(_) ->
      case project.javascript_source_maps(project) {
        Error(message) -> fail(message)
        Ok(False) ->
          fail(
            "JavaScript coverage needs source maps. Add "
            <> "[javascript] source_maps = true to gleam.toml.",
          )
        Ok(True) -> {
          let c8 = case ffi.which("c8") {
            Error(_) -> {
              fail(
                "JavaScript coverage requires c8 on PATH. Install c8 and retry.",
              )
              ""
            }
            Ok(path) -> path
          }
          let gleam = case ffi.which("gleam") {
            Error(message) -> {
              fail("Could not find gleam: " <> message)
              ""
            }
            Ok(path) -> path
          }
          case build_javascript_if_needed(project, options.no_build) {
            Error(message) -> fail(message)
            Ok(_) -> {
              let report_dir = project.root <> "/build/glcov-js"
              ffi.delete_file(report_dir <> "/lcov.info")
              let status =
                ffi.run(
                  c8,
                  [
                    "--reporter=lcovonly",
                    "--report-dir",
                    report_dir,
                    gleam,
                    "test",
                    "--target",
                    "javascript",
                  ],
                  project.root,
                )
              let lcov_path = report_dir <> "/lcov.info"
              case ffi.read_file(lcov_path) {
                Error(message) ->
                  fail("c8 did not write " <> lcov_path <> ": " <> message)
                Ok(contents) ->
                  case lcov.parse(contents) {
                    Error(message) -> fail(message)
                    Ok(records) -> {
                      let records =
                        records
                        |> list.filter_map(fn(record) {
                          let #(source, lines) = record
                          case js_source_path(project, source) {
                            Error(_) -> Error(Nil)
                            Ok(path) ->
                              case glob.matches_any(options.excludes, path) {
                                True -> Error(Nil)
                                False -> Ok(#(path, lines))
                              }
                          }
                        })
                      let report = coverage.from_source_lines(records)
                      case coverage.total_lines(report) {
                        0 ->
                          fail(
                            "c8 reported no project .gleam lines. Check "
                            <> "[javascript] source_maps = true and the c8 version.",
                          )
                        _ -> report_and_exit(project, options, report, status)
                      }
                    }
                  }
              }
            }
          }
        }
      }
  }
}

fn build_javascript_if_needed(
  project: project.Project,
  no_build: Bool,
) -> Result(Nil, String) {
  case no_build {
    True ->
      case ffi.is_dir(project.js_build_dir(project)) {
        True -> Ok(Nil)
        False ->
          Error(
            "No JavaScript build artefacts found at "
            <> project.js_build_dir(project)
            <> ". Run `gleam build --target javascript` first or drop --no-build.",
          )
      }
    False -> project.build_target(project, "javascript")
  }
}

fn js_source_path(
  project: project.Project,
  source: String,
) -> Result(String, Nil) {
  let normal = lcov.normalise_path(source)
  let absolute_prefix =
    lcov.normalise_path(project.js_build_dir(project)) <> "/"
  let relative_prefix = "build/dev/javascript/" <> project.name <> "/"
  let relative = case string.starts_with(normal, absolute_prefix) {
    True -> strip_prefix(normal, absolute_prefix)
    False ->
      case string.starts_with(normal, relative_prefix) {
        True -> strip_prefix(normal, relative_prefix)
        False -> ""
      }
  }
  case relative {
    "" -> Error(Nil)
    _ -> {
      let source_path = "src/" <> relative
      case ffi.file_exists(project.root <> "/" <> source_path) {
        True -> Ok(source_path)
        False -> Error(Nil)
      }
    }
  }
}

fn strip_prefix(value: String, prefix: String) -> String {
  string.slice(
    value,
    string.length(prefix),
    string.length(value) - string.length(prefix),
  )
}

fn build_if_needed(
  project: project.Project,
  no_build: Bool,
  ebin: String,
) -> Result(Nil, String) {
  case no_build {
    True ->
      case ffi.is_dir(ebin) {
        True -> Ok(Nil)
        False ->
          Error(
            "No build artefacts found at "
            <> ebin
            <> ". Run `gleam build` first or drop --no-build.",
          )
      }
    False -> project.build(project)
  }
}

fn add_code_paths(project: project.Project) -> Result(Nil, String) {
  let ebins = ffi.find_ebins(project.root)
  case ebins {
    [] ->
      Error(
        "No build/dev/erlang/*/ebin directories found after building. Is this a Gleam project?",
      )
    _ -> {
      ffi.add_code_paths(ebins)
      Ok(Nil)
    }
  }
}

fn run_with_paths(
  project: project.Project,
  options: args.Options,
  app: String,
  ebin: String,
  start_app: Bool,
) -> Nil {
  case project.default_target_is_javascript(project) {
    True -> {
      let _ =
        ffi.eprintln(
          "glcov: gleam.toml targets JavaScript by default; using the Erlang target. "
          <> "Run the CLI with `gleam run --target erlang -m glcov -- run` for consistent output.",
        )
      Nil
    }
    False -> Nil
  }

  let modules = case select_coverage_modules(project, options, ebin) {
    Error(message) -> {
      let _ = ffi.eprintln("glcov: " <> message)
      ffi.halt(2)
      []
    }
    Ok(modules) -> modules
  }
  case modules {
    [] ->
      fail(
        "No coverable Gleam modules found under "
        <> ebin
        <> ". Expected src/**/*.gleam modules in the project's ebin directory.",
      )
    _ -> {
      case options.verbose {
        True -> {
          io.println(
            "Selected " <> int.to_string(list.length(modules)) <> " module(s):",
          )
          modules
          |> list.each(fn(module) { io.println("  " <> module.source) })
        }
        False -> Nil
      }

      case cover.start_and_compile(modules) {
        Error(message) -> {
          cover.stop()
          fail(message)
        }
        Ok(_) -> {
          let app_started = case start_app {
            True ->
              case ffi.ensure_app_started(app) {
                Error(message) ->
                  Error(
                    "Could not start application " <> app <> ": " <> message,
                  )
                Ok(_) -> Ok(Nil)
              }
            False -> Ok(Nil)
          }

          case app_started {
            Error(message) -> {
              cover.stop()
              fail(message)
            }
            Ok(_) -> {
              let use_color = case options.no_color {
                True -> False
                False -> True
              }
              let test_status = runner.run(project.root, use_color)
              let analysis = cover.analyse(modules)
              let function_analysis = cover.analyse_functions(modules)
              cover.stop()

              case analysis {
                Error(message) -> fail(message)
                Ok(rows) -> {
                  let function_rows = case function_analysis {
                    Ok(functions) -> functions
                    Error(message) -> {
                      let _ =
                        ffi.eprintln(
                          "glcov: function coverage unavailable: " <> message,
                        )
                      []
                    }
                  }
                  let coverage_report =
                    coverage.from_modules_with_functions(rows, function_rows)
                  case coverage.total_lines(coverage_report) {
                    0 ->
                      fail(
                        "No executable Gleam lines were found in the selected modules. "
                        <> "Check that the project builds for Erlang and that src/ contains code.",
                      )
                    _ ->
                      report_and_exit(
                        project,
                        options,
                        coverage_report,
                        test_status,
                      )
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn select_coverage_modules(
  project: project.Project,
  options: args.Options,
  ebin: String,
) -> Result(List(cover.SelectedModule), String) {
  let root_modules = cover.select_modules(ebin, options.excludes)
  let dependencies = case options.use_path_deps {
    False -> Ok([])
    True -> project.path_dependencies(project)
  }
  case dependencies {
    Error(message) -> Error(message)
    Ok(discovered) -> {
      let include_paths = options.include_deps
      let auto_paths =
        discovered
        |> list.map(fn(dependency) { dependency.path })
        |> list.unique
      let explicit = include_paths |> list.unique
      let paths =
        list.append(
          list.map(auto_paths, fn(path) { #(path, path) }),
          list.map(explicit, fn(path) { #(path, path) }),
        )
        |> list.unique
      list.fold(paths, Ok(root_modules), fn(result, entry) {
        case result {
          Error(message) -> Error(message)
          Ok(modules) -> {
            let #(path, prefix) = entry
            case include_dependency_modules(project, options, path, prefix) {
              Error(message) -> Error(message)
              Ok(included) -> merge_modules(modules, included)
            }
          }
        }
      })
    }
  }
}

fn include_dependency_modules(
  project: project.Project,
  options: args.Options,
  path: String,
  prefix: String,
) -> Result(List(cover.SelectedModule), String) {
  let resolved = project.resolve_path(project, path)
  case project.locate(Some(resolved)) {
    Error(message) ->
      Error("Could not read path dependency " <> path <> ": " <> message)
    Ok(dependency) -> {
      let ebin = project.ebin(project, dependency.name)
      case ffi.is_dir(ebin) {
        False ->
          Error(
            "No build artefacts for path dependency "
            <> dependency.name
            <> " at "
            <> ebin
            <> ". Run `gleam build` first.",
          )
        True -> {
          let modules =
            cover.select_modules_with_prefix(ebin, prefix, options.excludes)
          case modules {
            [] ->
              Error(
                "No coverable Gleam modules found in path dependency "
                <> dependency.name
                <> ".",
              )
            _ -> Ok(modules)
          }
        }
      }
    }
  }
}

fn merge_modules(
  selected: List(cover.SelectedModule),
  additional: List(cover.SelectedModule),
) -> Result(List(cover.SelectedModule), String) {
  list.fold(additional, Ok(selected), fn(result, module) {
    case result {
      Error(message) -> Error(message)
      Ok(selected) ->
        case
          list.find(selected, fn(candidate) {
            candidate.module == module.module
          })
        {
          Ok(existing) ->
            Error(
              "Module "
              <> module.module
              <> " is present in both "
              <> existing.source
              <> " and "
              <> module.source
              <> ".",
            )
          Error(_) -> Ok(list.append(selected, [module]))
        }
    }
  })
}

fn prof_command(options: args.ProfOptions, start_app: Bool) -> Nil {
  case project.locate(options.root) {
    Error(message) -> fail(message)
    Ok(project) ->
      case ffi.set_cwd(project.root) {
        Error(message) ->
          fail("Could not enter the project directory: " <> message)
        Ok(_) ->
          case project.check_toolchain(project) {
            Error(message) -> fail(message)
            Ok(_) -> {
              let app = project.app_name(project, options.app)
              let ebin = project.ebin(project, app)
              case build_if_needed(project, options.no_build, ebin) {
                Error(message) -> fail(message)
                Ok(_) ->
                  case add_code_paths(project) {
                    Error(message) -> fail(message)
                    Ok(_) -> {
                      let modules = cover.select_modules(ebin, [])
                      case modules {
                        [] ->
                          fail(
                            "No coverable Gleam modules found under "
                            <> ebin
                            <> ".",
                          )
                        _ -> {
                          let app_started = case start_app {
                            True ->
                              case ffi.ensure_app_started(app) {
                                Error(message) ->
                                  Error(
                                    "Could not start application "
                                    <> app
                                    <> ": "
                                    <> message,
                                  )
                                Ok(_) -> Ok(Nil)
                              }
                            False -> Ok(Nil)
                          }
                          case app_started {
                            Error(message) -> fail(message)
                            Ok(_) -> {
                              let use_color = case options.no_color {
                                True -> False
                                False -> True
                              }
                              case
                                prof.run(
                                  modules,
                                  project.root,
                                  options.mode,
                                  use_color,
                                )
                              {
                                Error(message) -> fail(message)
                                Ok(profile) -> {
                                  case prof.has_rows(profile) {
                                    True -> {
                                      case options.quiet {
                                        True -> Nil
                                        False ->
                                          io.println(prof.render(
                                            profile,
                                            options.top,
                                          ))
                                      }
                                      io.println(prof.render_summary(
                                        profile,
                                        options.top,
                                      ))
                                      let code = case
                                        prof.test_status(profile)
                                      {
                                        0 -> 0
                                        1 -> 1
                                        _ -> 2
                                      }
                                      ffi.halt(code)
                                    }
                                    False -> {
                                      io.println(prof.render_summary(
                                        profile,
                                        options.top,
                                      ))
                                      ffi.halt(2)
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
              }
            }
          }
      }
  }
}

fn report_and_exit(
  project: project.Project,
  options: args.Options,
  coverage_report: coverage.Report,
  test_status: Int,
) -> Nil {
  case options.quiet {
    True -> Nil
    False -> {
      io.println(report.render(coverage_report))
      io.println("")
    }
  }
  io.println(report.render_summary(coverage_report))

  let write_result = write_lcov(project, options, coverage_report)
  case write_result {
    Error(message) -> fail(message)
    Ok(_) -> {
      let gate_failed = case options.min_bp {
        None -> False
        Some(min_bp) -> {
          let ok = coverage.meets_minimum(coverage_report, min_bp)
          case ok {
            True -> False
            False -> {
              let _ =
                ffi.eprintln(
                  "glcov: coverage "
                  <> coverage.percentage_string(coverage_report)
                  <> "% is below the minimum "
                  <> args.format_percent(min_bp)
                  <> "%.",
                )
              True
            }
          }
        }
      }

      let exit_code = case test_status {
        2 -> 2
        1 -> 1
        _ ->
          case gate_failed {
            True -> 1
            False -> 0
          }
      }
      ffi.halt(exit_code)
    }
  }
}

fn write_lcov(
  project: project.Project,
  options: args.Options,
  coverage_report: coverage.Report,
) -> Result(Nil, String) {
  case options.no_lcov {
    True -> Ok(Nil)
    False -> {
      let relative_path = case options.lcov {
        Some(path) -> path
        None -> "coverage/lcov.info"
      }
      let absolute_path = case project.is_absolute_path(relative_path) {
        True -> relative_path
        False -> project.root <> "/" <> relative_path
      }
      case ffi.write_file(absolute_path, lcov.render(coverage_report)) {
        Error(message) -> Error("Could not write lcov: " <> message)
        Ok(_) -> {
          io.println("Wrote " <> relative_path)
          Ok(Nil)
        }
      }
    }
  }
}

fn fail(message: String) -> Nil {
  let _ = ffi.eprintln("glcov: " <> message)
  ffi.halt(2)
}

fn help_text() -> String {
  "glcov " <> version <> " - line coverage and profiling for Gleam projects

Usage:
  gleam run -m glcov -- run [OPTIONS]

Options:
  --min <PCT>        Fail when total line coverage is below PCT (0-100, up to
                     two decimal places)
  --lcov <PATH>      Write lcov to PATH (default: coverage/lcov.info)
  --no-lcov          Do not write an lcov file
  --exclude <GLOB>   Skip source paths matching GLOB (repeatable)
  --include-dep <PATH>
                     Include a local path dependency (repeatable)
  --no-path-deps     Do not include path dependencies from gleam.toml
  --target <TARGET>  erlang (default) or javascript
  --quiet            Print only the summary
  --no-color         Disable coloured test output
  --no-build         Reuse existing build artefacts
  --root <DIR>       Project directory (default: nearest gleam.toml)
  --app <NAME>       Root application name (default: gleam.toml name)
  --verbose          Print selected modules and build details
  --help             Show this help
  --version          Show the version

Profiling:
  gleam run -m glcov -- prof test [--mode call_time|call_count|self_time] [--top N]

The Erlang backend builds with `gleam build`, runs EUnit/gleeunit, and collects
coverage with Erlang's cover. The JavaScript backend requires c8 and
[javascript] source_maps = true in gleam.toml."
}
