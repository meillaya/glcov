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
