# Profiler

The profiler runs the test suite under an Erlang tracing tool and maps each module, function, and arity to a `.gleam` function definition line.

```sh
gleam run --target erlang -m glcov -- prof test --mode call_time --top 20
```

Escript mode works too:

```sh
./glcov.escript prof test --mode call_count
```

## Modes

`--mode call_time` uses tprof and reports accumulated inclusive time per function in microseconds. `--mode call_count` uses tprof and reports call counts with lower overhead.

`--mode self_time` uses fprof and reports own time per function. Own time excludes time spent in called functions.

`--top <N>` sets how many rows to print. The default is 20.

## Output

```text
Location                     Function       Calls      Time (us)        %
src/fixture_bench.gleam:3    hot/1            200           8123    91.42
src/fixture_bench.gleam:7    warm/1            40            762     8.58
Profile: call_time (inclusive time, us), 2 function(s) in project code, top 20 shown
```

Self time uses an `Own (us)` column and a `self_time (own time, us)` summary.

Rows are limited to project source modules. Test modules, dependencies, generated modules, and anonymous functions are skipped.

## Limits

The profiler is function-level. BEAM tracing does not provide a line profiler, so there is no per-line heat map.

`call_time` includes time spent in nested calls. Use `call_count` when call volume matters, or `self_time` when own time matters.

`call_time` and `call_count` need Erlang/OTP 27 or newer because tprof is experimental there. `self_time` uses fprof and works on OTP 26, but fprof tracing slows the suite down and writes trace data to disk.

Passing or failing tests both produce a profile. A test failure makes the command exit 1 after the profile is printed.
