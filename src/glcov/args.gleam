import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Options {
  Options(
    min_bp: Option(Int),
    lcov: Option(String),
    no_lcov: Bool,
    excludes: List(String),
    include_deps: List(String),
    use_path_deps: Bool,
    quiet: Bool,
    no_color: Bool,
    no_build: Bool,
    root: Option(String),
    app: Option(String),
    target: Target,
    verbose: Bool,
  )
}

pub type Command {
  Run(Options)
  Prof(ProfOptions)
  Help
  Version
}

pub type Target {
  ErlangTarget
  JavascriptTarget
}

pub type ProfileMode {
  CallTime
  CallCount
  SelfTime
}

pub type ProfOptions {
  ProfOptions(
    mode: ProfileMode,
    top: Int,
    root: Option(String),
    app: Option(String),
    no_build: Bool,
    no_color: Bool,
    quiet: Bool,
  )
}

pub fn default_prof_options() -> ProfOptions {
  ProfOptions(
    mode: CallTime,
    top: 20,
    root: None,
    app: None,
    no_build: False,
    no_color: False,
    quiet: False,
  )
}

pub fn default_options() -> Options {
  Options(
    min_bp: None,
    lcov: None,
    no_lcov: False,
    excludes: [],
    include_deps: [],
    use_path_deps: True,
    quiet: False,
    no_color: False,
    no_build: False,
    root: None,
    app: None,
    target: ErlangTarget,
    verbose: False,
  )
}

pub fn parse(argv: List(String)) -> Result(Command, String) {
  case argv {
    [] -> Ok(Help)
    [first, ..rest] ->
      case first {
        "run" -> parse_run(rest, default_options())
        "prof" -> parse_prof(rest, default_prof_options())
        "--help" | "-h" -> Ok(Help)
        "--version" | "-V" -> Ok(Version)
        other -> Error("Unknown command: " <> other)
      }
  }
}

fn parse_run(
  arguments: List(String),
  options: Options,
) -> Result(Command, String) {
  case arguments {
    [] -> Ok(Run(options))
    [argument, ..rest] ->
      case argument {
        "--help" | "-h" -> Ok(Help)
        "--version" | "-V" -> Ok(Version)
        _ -> {
          let #(flag, inline_value) = split_inline(argument)
          case flag {
            "--min" ->
              case value_for(flag, inline_value, rest) {
                Ok(#(value, rest)) ->
                  case parse_percent(value) {
                    Ok(min_bp) ->
                      parse_run(rest, Options(..options, min_bp: Some(min_bp)))
                    Error(message) -> Error(message)
                  }
                Error(message) -> Error(message)
              }
            "--lcov" ->
              case value_for(flag, inline_value, rest) {
                Ok(#(value, rest)) ->
                  parse_run(rest, Options(..options, lcov: Some(value)))
                Error(message) -> Error(message)
              }
            "--exclude" ->
              case value_for(flag, inline_value, rest) {
                Ok(#(value, rest)) ->
                  parse_run(
                    rest,
                    Options(..options, excludes: [value, ..options.excludes]),
                  )
                Error(message) -> Error(message)
              }
            "--include-dep" ->
              case value_for(flag, inline_value, rest) {
                Ok(#(value, rest)) ->
                  parse_run(
                    rest,
                    Options(..options, include_deps: [
                      value,
                      ..options.include_deps
                    ]),
                  )
                Error(message) -> Error(message)
              }
            "--no-path-deps" ->
              parse_run(rest, Options(..options, use_path_deps: False))
            "--root" ->
              case value_for(flag, inline_value, rest) {
                Ok(#(value, rest)) ->
                  parse_run(rest, Options(..options, root: Some(value)))
                Error(message) -> Error(message)
              }
            "--app" ->
              case value_for(flag, inline_value, rest) {
                Ok(#(value, rest)) ->
                  parse_run(rest, Options(..options, app: Some(value)))
                Error(message) -> Error(message)
              }
            "--target" ->
              case value_for(flag, inline_value, rest) {
                Ok(#(value, rest)) ->
                  case parse_target(value) {
                    Ok(target) ->
                      parse_run(rest, Options(..options, target: target))
                    Error(message) -> Error(message)
                  }
                Error(message) -> Error(message)
              }
            "--no-lcov" -> parse_run(rest, Options(..options, no_lcov: True))
            "--quiet" -> parse_run(rest, Options(..options, quiet: True))
            "--no-color" -> parse_run(rest, Options(..options, no_color: True))
            "--no-build" -> parse_run(rest, Options(..options, no_build: True))
            "--verbose" -> parse_run(rest, Options(..options, verbose: True))
            _ -> Error("Unknown option: " <> argument)
          }
        }
      }
  }
}

fn parse_prof(
  arguments: List(String),
  options: ProfOptions,
) -> Result(Command, String) {
  case arguments {
    [] -> Error("The profiler needs a subcommand: use `prof test`.")
    ["test", ..rest] -> parse_prof_options(rest, options)
    ["--help"] -> Ok(Help)
    ["-h"] -> Ok(Help)
    [other, ..] -> Error("Unknown profiler command: " <> other)
  }
}

fn parse_prof_options(
  arguments: List(String),
  options: ProfOptions,
) -> Result(Command, String) {
  case arguments {
    [] -> Ok(Prof(options))
    ["--help"] -> Ok(Help)
    ["-h"] -> Ok(Help)
    [argument, ..rest] -> {
      let #(flag, inline_value) = split_inline(argument)
      case flag {
        "--mode" ->
          case value_for(flag, inline_value, rest) {
            Error(message) -> Error(message)
            Ok(#(value, rest)) ->
              case parse_profile_mode(value) {
                Error(message) -> Error(message)
                Ok(mode) ->
                  parse_prof_options(rest, ProfOptions(..options, mode: mode))
              }
          }
        "--top" ->
          case value_for(flag, inline_value, rest) {
            Error(message) -> Error(message)
            Ok(#(value, rest)) ->
              case int.parse(value) {
                Ok(top) if top > 0 ->
                  parse_prof_options(rest, ProfOptions(..options, top: top))
                _ -> Error("--top must be a positive integer")
              }
          }
        "--root" ->
          case value_for(flag, inline_value, rest) {
            Error(message) -> Error(message)
            Ok(#(value, rest)) ->
              parse_prof_options(
                rest,
                ProfOptions(..options, root: Some(value)),
              )
          }
        "--app" ->
          case value_for(flag, inline_value, rest) {
            Error(message) -> Error(message)
            Ok(#(value, rest)) ->
              parse_prof_options(rest, ProfOptions(..options, app: Some(value)))
          }
        "--no-build" ->
          parse_prof_options(rest, ProfOptions(..options, no_build: True))
        "--no-color" ->
          parse_prof_options(rest, ProfOptions(..options, no_color: True))
        "--quiet" ->
          parse_prof_options(rest, ProfOptions(..options, quiet: True))
        "--version" | "-V" -> Ok(Version)
        _ -> Error("Unknown profiler option: " <> argument)
      }
    }
  }
}

fn parse_target(value: String) -> Result(Target, String) {
  case value {
    "erlang" -> Ok(ErlangTarget)
    "javascript" -> Ok(JavascriptTarget)
    _ -> Error("--target must be erlang or javascript")
  }
}

fn parse_profile_mode(value: String) -> Result(ProfileMode, String) {
  case value {
    "call_time" -> Ok(CallTime)
    "call_count" -> Ok(CallCount)
    "self_time" -> Ok(SelfTime)
    _ -> Error("--mode must be call_time, call_count, or self_time")
  }
}

fn split_inline(argument: String) -> #(String, Option(String)) {
  case string.split(argument, "=") {
    [flag, first, ..rest] -> #(flag, Some(string.join([first, ..rest], "=")))
    _ -> #(argument, None)
  }
}

fn value_for(
  flag: String,
  inline_value: Option(String),
  rest: List(String),
) -> Result(#(String, List(String)), String) {
  case inline_value {
    Some(value) ->
      case value {
        "" -> Error(flag <> " requires a value")
        _ -> Ok(#(value, rest))
      }
    None ->
      case rest {
        [value, ..rest] -> Ok(#(value, rest))
        [] -> Error(flag <> " requires a value")
      }
  }
}

/// Parse a percentage into basis points (1/100th of a percent).
///
/// `80` -> 8000, `80.5` -> 8050, `80.05` -> 8005.
/// More than two decimal places is rejected.
pub fn parse_percent(value: String) -> Result(Int, String) {
  let parts = string.split(value, ".")
  case parts {
    [whole] ->
      case int.parse(whole) {
        Ok(number) if number >= 0 && number <= 100 -> Ok(number * 100)
        _ -> Error("--min must be a percentage between 0 and 100")
      }
    [whole, fraction] -> {
      let whole_number = int.parse(whole)
      let fraction_length = string.length(fraction)
      let fraction_number = int.parse(fraction)
      case whole_number, fraction_number {
        Ok(whole), Ok(fraction) -> {
          let length = fraction_length
          case whole >= 0 && whole <= 100 && length >= 1 && length <= 2 {
            True -> {
              let padded = fraction * pow10(2 - length)
              let basis_points = whole * 100 + padded
              case basis_points <= 10_000 {
                True -> Ok(basis_points)
                False -> Error("--min must be a percentage between 0 and 100")
              }
            }
            False -> Error("--min must have at most two decimal places")
          }
        }
        _, _ -> Error("--min must have at most two decimal places")
      }
    }
    _ -> Error("--min must be a percentage between 0 and 100")
  }
}

fn pow10(power: Int) -> Int {
  case power {
    0 -> 1
    1 -> 10
    _ -> 100
  }
}

pub fn format_percent(basis_points: Int) -> String {
  let whole = basis_points / 100
  let fraction = basis_points % 100
  int.to_string(whole) <> "." <> format_fraction(fraction)
}

fn format_fraction(fraction: Int) -> String {
  case fraction < 10 {
    True -> "0" <> int.to_string(fraction)
    False -> int.to_string(fraction)
  }
}

/// Sort and deduplicate options for deterministic tests and output.
pub fn normalise(options: Options) -> Options {
  Options(
    ..options,
    excludes: list.unique(options.excludes),
    include_deps: list.unique(options.include_deps),
  )
}
