# Usage

## Install

Add glcov as a test dependency:

```sh
gleam add --dev glcov
```

Run it from the project root:

```sh
gleam run --target erlang -m glcov -- run
```

Use `--target erlang` when `gleam.toml` defaults to JavaScript but the CLI runs on Erlang. The command builds the selected backend, runs the tests, and writes coverage.

## Command reference

```text
gleam run --target erlang -m glcov -- run [OPTIONS]
```

| Option | Default | Meaning |
| --- | --- | --- |
| `--target <TARGET>` | `erlang` | `erlang` or `javascript`. |
| `--min <PCT>` | none | Fail when total line coverage is below PCT. Accepts 0 to 100 with up to two decimals. |
| `--lcov <PATH>` | `coverage/lcov.info` | Write lcov to PATH. |
| `--no-lcov` | off | Skip the lcov file. |
| `--exclude <GLOB>` | none | Skip source paths matching GLOB. Repeatable. |
| `--include-dep <PATH>` | none | Include a local path dependency. Repeatable. |
| `--no-path-deps` | off | Do not include path dependencies from `gleam.toml`. |
| `--quiet` | off | Print the summary only. |
| `--no-color` | off | Disable coloured test output. |
| `--no-build` | off | Reuse existing build artefacts. |
| `--root <DIR>` | nearest `gleam.toml` | Project directory. |
| `--app <NAME>` | `name` from `gleam.toml` | Root application name. |
| `--verbose` | off | Print selected modules. |
| `--help`, `--version` | | Print help or the version. |

Exit codes:

| Code | Meaning |
| --- | --- |
| 0 | Tests passed and the coverage gate passed. |
| 1 | Tests failed or coverage was below `--min`. Coverage is still written when the test process can finish. |
| 2 | Usage, configuration, build, or tool error. |

## Path dependencies

Direct path dependencies under `[dependencies]` are included in coverage automatically. Their files appear in the table and lcov with paths relative to the project root. They count toward `--min`.

Development dependencies are skipped because tools such as glcov are often declared there as path dependencies. Use `--include-dep` to add one explicitly:

```sh
gleam run --target erlang -m glcov -- run --include-dep ../shared
```

`--no-path-deps` keeps the root package only. A missing path, missing build output, or duplicate module name stops the run with exit code 2.

## JavaScript

The JavaScript backend runs `gleam test --target javascript` under c8:

```sh
gleam run --target erlang -m glcov -- run --target javascript
```

Prerequisites:

- `c8` on `PATH` (the CI job pins 10.1.3).
- `[javascript] source_maps = true` in `gleam.toml`.
- Node available to c8.

glcov maps c8 paths under `build/dev/javascript/<app>/` back to `src/` and keeps only files that exist there. Test modules, dependencies, and generated files are skipped. JavaScript coverage is line-only in this release.

## lcov output

Erlang coverage writes line and function records:

```lcov
TN:
SF:src/fixture_basic.gleam
FN:1,classify/1
FN:9,untested/0
FNDA:2,classify/1
FNDA:0,untested/0
FNF:2
FNH:1
DA:2,1
DA:3,1
DA:4,1
DA:5,0
DA:10,0
LF:5
LH:3
end_of_record
```

`DA` uses `1` for a covered line and `0` for an uncovered line. `FN` and `FNDA` describe functions, and `FNF` and `FNH` give function totals. Erlang cover does not provide branch data, so there are no `BRDA` records.

JavaScript output is line-only. Generate HTML with lcov's `genhtml`:

```sh
genhtml coverage/lcov.info -o coverage/html
```

## Test setup

If `test/glcov_setup.gleam` exports `setup/0`, glcov calls it after the application starts and before EUnit. Use it for logger configuration or process-wide state that a custom test main would normally set.

```gleam
pub fn setup() -> Nil {
  wisp.configure_logger()
}
```

Setup failures stop the run with exit code 2.

## Escript

Build the standalone escript:

```sh
bash scripts/build_escript.sh
./glcov.escript run --min 85
```

The escript builds the project, starts it after cover instrumentation, and then runs tests. Use the escript when `gleam.toml` sets `[erlang] application_start_module`: `gleam run` would start that application before glcov runs, and a fresh clone may not have the start callback compiled yet.

The escript adds the project's build paths before loading its own CLI code. The project's `gleam_stdlib` version is therefore used for tests even when it differs from the copy bundled in the escript.

The escript supports the Erlang backend only. For JavaScript coverage, run the CLI from a checkout with c8 installed.

## Nix

The flake exposes a development shell and a packaged CLI:

```sh
nix develop --no-pure-eval
nix build .#glcov
./result/bin/glcov run
nix run .# -- run --min 85
```

Use `--no-pure-eval` for the development shell. Devenv needs the working directory, and pure flake evaluation hides it.

The Nix package pins Gleam 1.19.2 and Erlang/OTP 28. Its wrapper puts the pinned `gleam`, `erlang`, and `git` on `PATH`. c8 is not packaged; JavaScript coverage needs it on `PATH`.

## CI

```yaml
- uses: erlef/setup-beam@v1
  with:
    otp-version: "28"
    gleam-version: "1.19.2"
- run: gleam deps download
- run: gleam run --target erlang -m glcov -- run --min 85 --lcov coverage/lcov.info
- uses: codecov/codecov-action@v5
  with:
    files: coverage/lcov.info
```

For a JavaScript job, install c8 and enable source maps. For projects with `[erlang] application_start_module`, run `gleam build` first and pass `--no-build`:

```sh
gleam build
gleam run --target erlang -m glcov -- run --no-build --min 85
```
