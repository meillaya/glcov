# glcov

Line coverage and a profiler for Gleam projects, with Erlang and JavaScript backends.

glcov is for Gleam teams that want a coverage table, `coverage/lcov.info`, and a CI gate without changing test files. It covers direct path dependencies and profiles test suites at function level.

## Quick start

```sh
gleam add --dev glcov
gleam run --target erlang -m glcov -- run
```

The default backend builds the project, runs its EUnit or gleeunit tests under Erlang `cover`, and maps counted lines back to `.gleam` files.

```text
2 passed, no failures
File                       Lines   Covered   Uncovered        %
src/fixture_basic.gleam        5         3           2    60.00
TOTAL                          5         3           2    60.00

Coverage: 60.00% (3/5 lines covered)
Wrote coverage/lcov.info
```

The `gleam` CLI has no plugin system, so `gleam coverage` is not a command. glcov installs as a dev dependency and runs as a module.

## CI

```yaml
- uses: erlef/setup-beam@v1
  with:
    otp-version: "28"
    gleam-version: "1.19.2"
- run: gleam deps download
- run: gleam run --target erlang -m glcov -- run --min 85
- uses: codecov/codecov-action@v5
  with:
    files: coverage/lcov.info
```

## Other backends and modes

- JavaScript: `gleam run --target erlang -m glcov -- run --target javascript`. Requires `c8` and `[javascript] source_maps = true`.
- Path dependencies: direct runtime path dependencies in `gleam.toml` are included automatically. Use `--include-dep <PATH>` for dev dependencies or undeclared packages, and `--no-path-deps` to opt out.
- Self time: `gleam run --target erlang -m glcov -- prof test --mode self_time`.
- Escript: build with `bash scripts/build_escript.sh` and run `./glcov.escript run` for stateful applications.
- Nix: `nix build .#glcov`, then run `./result/bin/glcov run`.

## Real-project checks

These public projects were run against glcov with their own test suites:

| Project | Tests | Line coverage | Notes |
| --- | --- | --- | --- |
| `gleeunit` | 25 passed | 9.43% | Most tests target JavaScript, so the low coverage is expected. |
| `gleam_stdlib` | 1548 passed | 80.05% | |
| `wisp` | 164 passed | 86.44% | Fresh build with the escript; uses `gleam_stdlib` 0.70. |

The `wisp` run checks the older stdlib path. The other runs use their current dependencies.

## Documentation

- [Usage and command reference](docs/usage.md)
- [Coverage limits and behaviour](docs/limitations.md)
- [Profiler](docs/profiler.md)
- [Development, escript and Nix](docs/development.md)

## Requirements

The Erlang backend needs Gleam 1.19 or newer, Erlang/OTP 26 or newer, and `gleam_stdlib` 0.70 or newer. The JavaScript backend needs Node and `c8` on `PATH`, plus `[javascript] source_maps = true`. The `call_time` and `call_count` profiler modes need OTP 27; `self_time` needs OTP 26.

## Licence

Apache-2.0. See [LICENCE](LICENCE).
