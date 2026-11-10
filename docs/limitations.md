# Coverage limits and behaviour

glcov reports executable lines from Erlang cover. The reported line numbers are original `.gleam` lines because Gleam 1.19 and newer store that metadata in each beam.

## Line counting

Erlang cover counts lines in expression bodies. Lines that hold a function head, a blank line, or a comment are not counted. A function that is never called shows its body lines as uncovered; its `pub fn` line does not appear in the report.

The report covers the root package only. Dependencies, test modules, `dev/` modules, and the generated `<app>@@main` module are left out.

There is no branch coverage. Erlang cover does not expose branch data, and glcov does not invent a branch denominator.

## Erlang target only

Coverage collection uses Erlang `cover` and `beam_lib`. JavaScript output, Node, Deno, and browser tests are not covered. Use Node's V8 coverage or c8 for the JavaScript target.

## Test execution

glcov discovers files under `test/`, keeps modules that export an EUnit test function, and runs them with EUnit. When `gleeunit` is present, glcov uses its reporter and options so output matches `gleam test`.

The project's `<app>_test:main/0` function is not called. Projects whose test main only calls `gleeunit.main()` behave the same as `gleam test`. Projects that perform setup in the test main need to move that setup somewhere else or use a custom runner.

## Application start

In `gleam run` mode the root application is already started by the runner before glcov receives control. Lines that execute during application start are not counted, and tests that expect a fresh application may behave differently.

A project with `[erlang] application_start_module` can fail before glcov starts on a fresh clone, because `gleam run` starts the application before the project has been compiled. Use the escript or run `gleam build` first:

```sh
gleam build
gleam run --target erlang -m glcov -- run --no-build
```

The escript starts the application after cover instrumentation, so application-start lines are counted in that mode.

## Processes that stop the VM

A test that calls `erlang:halt/1` or `init:stop/1` ends the VM before glcov can collect coverage. The command exits without a report in that case.

## Custom test runners

glcov targets EUnit and gleeunit. Other test runners are not detected automatically. The CLI still runs the project's tests only when they are EUnit tests; a project with a custom runner should keep using that runner until a library hook exists.

## Version requirements

glcov needs Gleam 1.19 or newer for source line metadata, Erlang/OTP 26 or newer, and `gleam_stdlib` 0.70 or newer. The profiler needs OTP 27 or newer because it uses `tprof`.
