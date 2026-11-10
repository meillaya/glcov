# Changelog

## 0.2.0

- Added the source-mapped profiler: `glcov prof test` (function-level,
  `tprof`, OTP 27+; `call_time` and `call_count` modes).
- Added a standalone escript and `scripts/build_escript.sh` for stateful
  applications and zero-dependency CI use.
- Added the Nix flake: `devShells` from `devenv.nix`, a packaged
  self-contained `glcov` escript, `apps`, `checks`, and a formatter.
- Added integration coverage for the escript, stateful application start,
  EUnit fallback, nested test modules, and the profiler.
- Supports projects on `gleam_stdlib` 0.70+; the escript bootstraps project
  build paths so the project's stdlib version wins over its bundled copy.
- Test discovery preserves project order and only passes modules that export
  EUnit tests, matching gleeunit more closely on large real-world suites.

## 0.1.0

- Initial release.
- Erlang-target line coverage for the root Gleam package.
- Source-accurate `.gleam` line mapping through Gleam 1.19+ metadata.
- Console table, `coverage/lcov.info`, and `--min` CI gate.
- EUnit/gleeunit test discovery and execution without modifying test files.
- Excludes `test/`, `dev/`, generated `<app>@@main`, and user `--exclude`
  globs.
- JavaScript stubs so dual-target projects can keep glcov as a dev dependency;
  coverage itself is Erlang-only.
