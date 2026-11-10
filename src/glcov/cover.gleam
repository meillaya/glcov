import glcov/ffi
import glcov/glob
import gleam/list
import gleam/string

pub type SelectedModule {
  SelectedModule(module: String, source: String, beam: String)
}

/// Pick the root package's Gleam source modules for coverage.
///
/// Only `src/**/*.gleam` is included in 0.2.0. Test code, dev code, the
/// generated `<app>@@main` module, Erlang sources, and user `--exclude`
/// globs are skipped.
pub fn select_modules(
  ebin: String,
  excludes: List(String),
) -> List(SelectedModule) {
  ffi.beam_sources(ebin)
  |> list.filter_map(fn(entry) {
    let #(module, source, beam) = entry
    let normalised = normalise_source(source)
    case is_ignored(module, normalised, excludes) {
      True -> Error(Nil)
      False -> Ok(SelectedModule(module, normalised, beam))
    }
  })
  |> list.sort(by: fn(a, b) { string.compare(a.source, b.source) })
}

fn is_ignored(module: String, source: String, excludes: List(String)) -> Bool {
  case source {
    "" -> True
    _ ->
      !string.starts_with(source, "src/")
      || !string.ends_with(source, ".gleam")
      || string.ends_with(module, "@@main")
      || string.starts_with(source, "test/")
      || string.starts_with(source, "dev/")
      || glob.matches_any(excludes, source)
  }
}

fn normalise_source(source: String) -> String {
  string.replace(source, "\\", "/")
}

pub fn start_and_compile(modules: List(SelectedModule)) -> Result(Nil, String) {
  case ffi.cover_start() {
    Error(message) -> Error("Could not start cover: " <> message)
    Ok(_) -> {
      let beams = list.map(modules, fn(module) { module.beam })
      let failures = ffi.cover_compile(beams)
      case failures {
        [] -> Ok(Nil)
        _ ->
          Error(
            "Cover instrumentation failed:\n"
            <> string.join(
              list.map(failures, fn(failure) {
                let #(beam, reason) = failure
                "  " <> beam <> ": " <> reason
              }),
              "\n",
            ),
          )
      }
    }
  }
}

pub fn analyse(
  modules: List(SelectedModule),
) -> Result(List(#(String, String, List(#(Int, Bool)))), String) {
  let names = list.map(modules, fn(module) { module.module })
  case ffi.cover_analyse(names) {
    Error(message) -> Error("Cover analysis failed: " <> message)
    Ok(results) ->
      Ok(
        results
        |> list.map(fn(result) {
          let #(module, lines) = result
          #(module, source_for(modules, module), lines)
        })
        |> list.filter(fn(entry) {
          let #(_, source, _) = entry
          source != ""
        }),
      )
  }
}

/// Function coverage rows: `{source, name, line, arity, calls}`.
pub fn analyse_functions(
  modules: List(SelectedModule),
) -> Result(List(#(String, String, Int, Int, Int)), String) {
  let names = list.map(modules, fn(module) { module.module })
  case ffi.cover_analyse_functions(names) {
    Error(message) -> Error("Function coverage analysis failed: " <> message)
    Ok(results) ->
      Ok(
        modules
        |> list.flat_map(fn(module) {
          let calls = calls_for(results, module.module)
          ffi.beam_functions(module.beam)
          |> list.filter_map(fn(definition) {
            let #(name, arity, line) = definition
            case is_named_function(name) && line > 0 {
              False -> Error(Nil)
              True ->
                Ok(#(
                  module.source,
                  name,
                  line,
                  arity,
                  call_count(calls, name, arity),
                ))
            }
          })
        }),
      )
  }
}

fn calls_for(
  results: List(#(String, List(#(String, Int, Int)))),
  module: String,
) -> List(#(String, Int, Int)) {
  case
    list.find(results, fn(entry) {
      let #(candidate, _) = entry
      candidate == module
    })
  {
    Ok(#(_, calls)) -> calls
    Error(_) -> []
  }
}

fn call_count(
  calls: List(#(String, Int, Int)),
  name: String,
  arity: Int,
) -> Int {
  case
    list.find(calls, fn(entry) {
      let #(candidate_name, candidate_arity, _) = entry
      candidate_name == name && candidate_arity == arity
    })
  {
    Ok(#(_, _, calls)) -> calls
    Error(_) -> 0
  }
}

fn is_named_function(name: String) -> Bool {
  !string.starts_with(name, "-") && name != "module_info"
}

fn source_for(modules: List(SelectedModule), module: String) -> String {
  modules
  |> list.find(fn(candidate) { candidate.module == module })
  |> result_source
}

fn result_source(found: Result(SelectedModule, Nil)) -> String {
  case found {
    Ok(module) -> module.source
    Error(_) -> ""
  }
}

pub fn stop() -> Nil {
  ffi.cover_stop()
}
