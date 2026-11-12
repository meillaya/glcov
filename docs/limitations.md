# Coverage limits and behaviour

glcov supports two coverage backends. The Erlang backend reports executable lines from Erlang cover; the JavaScript backend reports lines from c8 and Gleam source maps.

## Erlang line counting

Erlang cover counts lines in expression bodies. Lines that hold a function head, a blank line, or a comment are not counted. A function that is never called shows its body lines as uncovered; its `pub fn` line does not appear in the report.

The root package is the default unit. Test modules, `dev/` modules, generated modules, and unselected dependencies are left out. Path dependencies under `[dependencies]` are included automatically and count toward the gate; `--include-dep` adds others, and `--no-path-deps` disables discovery.

There is no branch coverage. Erlang cover does not expose branch data.

## JavaScript line counting

The JavaScript backend runs the project through c8 with Gleam source maps. Lines map back to the files under `src/` that exist in the project, so test modules and dependencies do not enter the report.

c8 and Erlang cover count different line sets. A function head may be covered on JavaScript and omitted on Erlang. Compare percentages within one backend, not across backends.

JavaScript coverage is line-only. Function records are omitted, and there is no branch coverage.

## Backend requirements

The Erlang backend needs Erlang/OTP 26 or newer. The JavaScript backend needs Node, c8, and `[javascript] source_maps = true`.

The `call_time` and `call_count` profiler modes need OTP 27 and tprof. The `self_time` mode uses fprof and works on the OTP 26 floor, but tracing is slower.

## Test execution

glcov discovers files under `test/`, keeps modules that export an EUnit test function, and runs them with EUnit. When `gleeunit` is present, glcov uses its reporter and options so output matches `gleam test`. The JavaScript backend uses the project's normal `gleam test` path.

The project's `<app>_test:main/0` function is not called by the Erlang backend. Projects whose test main only calls `gleeunit.main()` behave the same as `gleam test`. Projects that perform setup in the test main can put that setup in `test/glcov_setup.gleam`; glcov calls its `setup/0` before EUnit. Other custom runner behaviour needs a library hook that does not exist yet.

## Application start

In `gleam run` mode the root application is already started by the runner before glcov receives control. Lines that execute during application start are not counted, and tests that expect a fresh application may behave differently.

A project with `[erlang] application_start_module` can fail before glcov starts on a fresh clone, because `gleam run` starts the application before the project has been compiled. Use the escript or run `gleam build` first:

```sh
gleam build
gleam run --target erlang -m glcov -- run --no-build
```

The escript starts the application after cover instrumentation, so application-start lines are counted in that mode. The JavaScript backend does not start an Erlang application.

## Processes that stop the VM

A test that calls `erlang:halt/1` or `init:stop/1` ends the VM before glcov can collect Erlang coverage. The command exits without a report in that case.

## Path dependencies

Only direct path dependencies are discovered. Transitive path dependencies are not walked. The dependency's `gleam.toml` must have a `name`, and its ebin must exist after `gleam build`.

Absolute, relative, and `..` paths are accepted. Source paths in lcov use forward slashes on every platform.

## Custom test runners

glcov targets EUnit and gleeunit. Other test runners are not detected automatically. A project with a custom runner should keep using that runner until a library hook exists.

## Version requirements

glcov needs Gleam 1.19 or newer for Erlang source line metadata and source maps, Erlang/OTP 26 or newer, and `gleam_stdlib` 0.70 or newer.
