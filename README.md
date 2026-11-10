# glcov

Line coverage and a function-level profiler for Gleam projects on the Erlang target.

glcov is for Gleam teams whose tests run on Erlang and who want a coverage table, `coverage/lcov.info`, and a CI gate without editing test files.

## Quick start

```sh
gleam add --dev glcov
gleam run --target erlang -m glcov -- run
```

The command builds the project, runs its EUnit or gleeunit tests under Erlang `cover`, and maps counted lines back to `.gleam` files.

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

## Other ways to run

- Build the escript with `bash scripts/build_escript.sh` and run `./glcov.escript run` for stateful applications or zero-dependency CI.
- Build the flake package with `nix build .#glcov` and run it with `./result/bin/glcov run`.
- Profile the test suite with `gleam run --target erlang -m glcov -- prof test`.

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

Gleam 1.19 or newer, Erlang/OTP 26 or newer, and `gleam_stdlib` 0.70 or newer.

## Licence

Apache-2.0. See [LICENCE](LICENCE).
