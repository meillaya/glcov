#!/usr/bin/env bash
# Build the self-contained glcov escript from the current checkout.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

gleam build --target erlang
escript nix/build_escript.escript \
  glcov.escript \
  build/dev/erlang/glcov/ebin \
  build/dev/erlang/gleam_stdlib/ebin
chmod +x glcov.escript
printf 'wrote %s/glcov.escript\n' "$ROOT"
