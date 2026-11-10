# Profiler

The profiler collects function-level call and time data from the test suite with Erlang's `tprof`, then maps each module, function, and arity to a `.gleam` function definition line.

```sh
gleam run --target erlang -m glcov -- prof test --mode call_time --top 20
```

Escript mode works too:

```sh
./glcov.escript prof test --mode call_count
```

## Modes

`--mode call_time` reports accumulated inclusive time per function in microseconds. `--mode call_count` reports call counts and has lower overhead.

`--top <N>` sets how many rows to print. The default is 20.

## Output

```text
Location                     Function       Calls      Time (us)        %
src/fixture_bench.gleam:3    hot/1            200           8123    91.42
src/fixture_bench.gleam:7    warm/1            40            762     8.58
Profile: call_time (inclusive time, us), 2 function(s) in project code, top 20 shown
```

Rows are limited to project source modules. Test modules, dependencies, generated modules, and anonymous functions are skipped.

## Limits

The profiler is function-level. BEAM tracing does not provide a line profiler, so there is no per-line heat map.

`call_time` is accumulated time from function entry to return, which includes time spent in nested calls. Use `call_count` when call volume matters more than timing.

The profiler needs Erlang/OTP 27 or newer. It is experimental because `tprof` is experimental in OTP 27.

Passing or failing tests both produce a profile. A test failure makes the command exit 1 after the profile is printed.
