import glcov/args
import glcov/cover
import glcov/coverage
import glcov/ffi
import glcov/lcov
import glcov/prof
import glcov/project
import glcov/report
import glcov/runner
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}

pub const version: String = "0.3.0"

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

  let modules = cover.select_modules(ebin, options.excludes)
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
  "glcov "
  <> version
  <> " - line coverage for Gleam projects on the Erlang target

Usage:
  gleam run -m glcov -- run [OPTIONS]

Options:
  --min <PCT>        Fail when total line coverage is below PCT (0-100, up to
                     two decimal places)
  --lcov <PATH>      Write lcov to PATH (default: coverage/lcov.info)
  --no-lcov          Do not write an lcov file
  --exclude <GLOB>   Skip source paths matching GLOB (repeatable)
  --quiet            Print only the summary
  --no-color         Disable coloured test output
  --no-build         Reuse existing build artefacts
  --root <DIR>       Project directory (default: nearest gleam.toml)
  --app <NAME>       Root application name (default: gleam.toml name)
  --verbose          Print selected modules and build details
  --help             Show this help
  --version          Show the version

Profiling:
  gleam run -m glcov -- prof test [--mode call_time|call_count] [--top N]

Run from the project root. The project is built for the Erlang target with
`gleam build`; tests are executed with EUnit/gleeunit and coverage is collected
with Erlang's cover. JavaScript coverage is not supported yet."
}
