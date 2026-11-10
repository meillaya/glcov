# Development, escript and Nix

## Environment

The development environment is a devenv shell:

```sh
devenv shell
```

It provides Gleam 1.19.2, Erlang/OTP 28, lcov, Node, and the tools used by the test suite. The first evaluation builds Gleam and takes several minutes. Later shells reuse the result.

The same `devenv.nix` is exposed as a flake development shell:

```sh
nix develop --no-pure-eval
```

## Checks

```sh
gleam format --check src test
gleam build --warnings-as-errors
gleam test
bash integration/run.sh
devenv test
```

`devenv test` runs the format check, a warnings-as-errors build, and the unit tests.

`integration/run.sh` builds the escript, then runs real fixture projects. Fixtures cover basic coverage, the minimum gate, failing tests, build failure, no tests, nested modules, the EUnit fallback, stateful application start, the profiler, flags, and `--no-build`.

The integration suite expects `gleam` and `escript` on `PATH`. The devenv shell provides both.

## Flake checks

```sh
nix flake check
nix build .#glcov
nix develop --no-pure-eval --command gleam test
```

`nix build .#glcov` builds the CLI as a self-contained escript from source. The Nix derivation copies only `src/` and generates a package configuration with a vendored `gleam_stdlib` path dependency. The wrapper includes the pinned Gleam, Erlang, and Git binaries.

## Release

Releases are tag driven. The release workflow runs the format check, build, and unit tests, builds `glcov.escript`, writes its checksum, publishes the Hex package, and attaches the escript and checksum to a GitHub release.

Set `HEXPM_API_KEY` in the repository secrets before tagging. Update `version` in `gleam.toml` and `pub const version` in `src/glcov/cli.gleam` before the tag.
