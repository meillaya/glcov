#!/usr/bin/env bash
# End-to-end checks for glcov. Run from anywhere; the script locates the
# repository root itself. It expects `gleam` to be on PATH (CI: setup-beam,
# local: devenv shell).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Path dependencies in fixtures are pinned to the checkout under test. A
# stale lock would hold the previous package version after a version bump.
find integration/fixtures -name manifest.toml -delete 2>/dev/null || true

GLEAM="${GLEAM_BIN:-gleam}"
ESCRIPT="$ROOT/glcov.escript"
failed=0

ensure_escript() {
  (cd "$ROOT" && bash scripts/build_escript.sh >/dev/null)
  [ -x "$ESCRIPT" ] || { fail "escript build did not produce $ESCRIPT"; exit 1; }
}

pass() {
  printf 'ok   %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  failed=1
}

contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*) return 0 ;;
    *) return 1 ;;
  esac
}

fixture_dir() {
  printf '%s/integration/fixtures/%s' "$ROOT" "$1"
}

run_cli() {
  local fixture="$1"
  shift
  (cd "$(fixture_dir "$fixture")" && "$GLEAM" run --target erlang -m glcov -- run "$@")
}

# Remove coverage output from a fixture so assertions cannot see stale data.
clean_coverage() {
  rm -rf "$(fixture_dir "$1")/coverage"
}

check_basic() {
  clean_coverage basic
  local output status
  set +e
  output="$(run_cli basic 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    fail "basic: expected exit 0, got $status"
    printf '%s\n' "$output"
    return
  fi
  contains "$output" "Coverage: 60.00% (3/5 lines covered)" \
    || { fail "basic: unexpected summary"; printf '%s\n' "$output"; }
  local lcov
  lcov="$(cat "$(fixture_dir basic)/coverage/lcov.info")"
  contains "$lcov" "SF:src/fixture_basic.gleam" || fail "basic: missing source record"
  contains "$lcov" "DA:2,1" || fail "basic: expected line 2 covered"
  contains "$lcov" "DA:5,0" || fail "basic: expected line 5 uncovered"
  contains "$lcov" "LF:5" || fail "basic: expected LF:5"
  contains "$lcov" "LH:3" || fail "basic: expected LH:3"
  contains "$lcov" "FN:1,classify/1" || fail "basic: missing function record"
  contains "$lcov" "FNDA:2,classify/1" || fail "basic: wrong function call count"
  contains "$lcov" "FNF:2" || fail "basic: expected FNF:2"
  contains "$lcov" "FNH:1" || fail "basic: expected FNH:1"
  [ -f "$(fixture_dir basic)/coverage/lcov.info" ] || fail "basic: no lcov file"
  pass "basic coverage and function records"
}

check_minimum() {
  clean_coverage basic
  local output status
  set +e
  output="$(run_cli basic --min 100 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 1 ]; then
    fail "minimum: expected exit 1, got $status"
    printf '%s\n' "$output"
    return
  fi
  contains "$output" "below the minimum 100.00%" || fail "minimum: missing gate message"
  [ -f "$(fixture_dir basic)/coverage/lcov.info" ] || fail "minimum: lcov not written on gate failure"
  pass "minimum gate"
}

check_failing_tests() {
  clean_coverage failing
  local output status
  set +e
  output="$(run_cli failing 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 1 ]; then
    fail "failing tests: expected exit 1, got $status"
    printf '%s\n' "$output"
    return
  fi
  contains "$output" "1 failures" || fail "failing tests: expected failure output"
  [ -f "$(fixture_dir failing)/coverage/lcov.info" ] || fail "failing tests: coverage not reported"
  pass "failing tests still report coverage"
}

check_build_failure() {
  local output status
  set +e
  output="$(run_cli build_failure 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 2 ]; then
    fail "build failure: expected exit 2, got $status"
    printf '%s\n' "$output"
    return
  fi
  contains "$output" "gleam build" || fail "build failure: missing build error"
  pass "build failure"
}

check_no_tests() {
  clean_coverage no_tests
  local output status
  set +e
  output="$(run_cli no_tests 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    fail "no tests: expected exit 0, got $status"
    printf '%s\n' "$output"
    return
  fi
  contains "$output" "no test modules" || fail "no tests: missing warning"
  [ -f "$(fixture_dir no_tests)/coverage/lcov.info" ] || fail "no tests: no lcov file"
  pass "no tests"
}

check_nested() {
  clean_coverage nested
  local output status
  set +e
  output="$(run_cli nested 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    fail "nested: expected exit 0, got $status"
    printf '%s\n' "$output"
    return
  fi
  local lcov
  lcov="$(cat "$(fixture_dir nested)/coverage/lcov.info")"
  contains "$lcov" "SF:src/fixture_nested.gleam" || fail "nested: missing top module"
  contains "$lcov" "SF:src/nested/helper.gleam" || fail "nested: missing nested module"
  contains "$lcov" "DA:6,0" || fail "nested: expected unused function line uncovered"
  pass "nested modules"
}

check_eunit_fallback() {
  clean_coverage eunit_only
  local output status
  set +e
  output="$(run_cli eunit_only 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    fail "eunit fallback: expected exit 0, got $status"
    printf '%s\n' "$output"
    return
  fi
  local lcov
  lcov="$(cat "$(fixture_dir eunit_only)/coverage/lcov.info")"
  contains "$lcov" "DA:2,1" || fail "eunit fallback: answer line not covered"
  contains "$lcov" "DA:6,1" || fail "eunit fallback: nested test module did not run"
  pass "eunit fallback and nested test modules"
}

check_stateful_escript() {
  ensure_escript
  clean_coverage stateful
  local output status
  set +e
  output="$(cd "$(fixture_dir stateful)" && escript "$ESCRIPT" run --quiet 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    fail "stateful escript: expected exit 0, got $status"
    printf '%s\n' "$output"
    return
  fi
  local lcov
  lcov="$(cat "$(fixture_dir stateful)/coverage/lcov.info")"
  contains "$lcov" "SF:src/fixture_stateful_marker.gleam" \
    || fail "stateful escript: app-start module missing from report"
  contains "$lcov" "DA:2,1" \
    || fail "stateful escript: app-start line was not covered"
  pass "stateful app started under cover (escript)"
}

check_stateful_gleam_run() {
  local fixture
  fixture="$(fixture_dir stateful)"
  clean_coverage stateful
  rm -rf "$fixture/build"

  local output status
  set +e
  output="$(cd "$fixture" && "$GLEAM" run --target erlang -m glcov -- run 2>&1)"
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    fail "stateful fresh gleam run: expected app-start failure"
  fi
  [ ! -f "$fixture/coverage/lcov.info" ] || fail "stateful fresh gleam run: unexpected lcov"
  pass "stateful fresh gleam run fails before glcov (application_start_module caveat)"

  (cd "$fixture" && "$GLEAM" build --target erlang >/dev/null)
  clean_coverage stateful
  set +e
  output="$(cd "$fixture" && "$GLEAM" run --target erlang -m glcov -- run --no-build --quiet 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    fail "stateful prebuilt gleam run: expected exit 0, got $status"
    printf '%s\n' "$output"
    return
  fi
  local lcov
  lcov="$(cat "$fixture/coverage/lcov.info")"
  contains "$lcov" "DA:2,0" || fail "stateful prebuilt: app-start line should be uncovered"
  pass "stateful prebuilt gleam run (app-start lines not counted)"
}

check_profiler() {
  local output status
  set +e
  output="$(cd "$(fixture_dir basic)" && "$GLEAM" run --target erlang -m glcov -- prof test --mode call_count --top 5 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    fail "profiler: expected exit 0, got $status"
    printf '%s\n' "$output"
    return
  fi
  contains "$output" "src/fixture_basic.gleam:1" || fail "profiler: missing mapped location"
  contains "$output" "classify/1" || fail "profiler: missing function/arity"
  contains "$output" "Profile: call_count" || fail "profiler: missing summary"

  ensure_escript
  set +e
  output="$(cd "$(fixture_dir basic)" && escript "$ESCRIPT" prof test --mode call_count --top 5 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ]; then
    fail "escript profiler: expected exit 0, got $status"
    printf '%s\n' "$output"
    return
  fi
  contains "$output" "classify/1" || fail "escript profiler: missing function/arity"
  pass "profiler (gleam run and escript)"
}

check_self_time() {
  local output status
  set +e
  output="$(cd "$(fixture_dir basic)" && "$GLEAM" run --target erlang -m glcov -- prof test --mode self_time --top 5 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] || { fail "self-time: expected exit 0, got $status"; printf '%s\n' "$output"; return; }
  contains "$output" "self_time (own time, us)" || fail "self-time: missing mode summary"
  contains "$output" "src/fixture_basic.gleam:1" || fail "self-time: missing source mapping"
  contains "$output" "classify/1" || fail "self-time: missing function row"

  set +e
  output="$(cd "$(fixture_dir failing)" && "$GLEAM" run --target erlang -m glcov -- prof test --mode self_time 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 1 ] || fail "self-time: failing suite expected exit 1, got $status"
  pass "self-time profiler"
}

check_js_coverage() {
  local output status
  set +e
  output="$(run_cli js_no_maps --target javascript 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 2 ] || fail "js source maps: expected exit 2, got $status"
  contains "$output" "source_maps = true" || fail "js source maps: missing hint"

  if ! command -v c8 >/dev/null 2>&1; then
    pass "JavaScript coverage (skipped: c8 not installed)"
    return
  fi

  clean_coverage js_target
  set +e
  output="$(run_cli js_target --target javascript --quiet 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] || { fail "js coverage: expected exit 0, got $status"; printf '%s\n' "$output"; return; }
  local lcov
  lcov="$(cat "$(fixture_dir js_target)/coverage/lcov.info")"
  contains "$lcov" "SF:src/fixture_js_target.gleam" || fail "js coverage: missing source record"
  contains "$lcov" "DA:1,1" || fail "js coverage: missing line record"
  pass "JavaScript coverage"
}

check_flags() {
  local output status
  set +e
  local version
  version="$(sed -n 's/^version = "\(.*\)"$/\1/p' "$ROOT/gleam.toml")"
  output="$(run_cli basic --version 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] && contains "$output" "glcov $version" || fail "version flag"
  set +e
  output="$(run_cli basic --help 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] && contains "$output" "Usage:" || fail "help flag"

  clean_coverage basic
  set +e
  output="$(run_cli basic --quiet --no-lcov 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] || fail "quiet/no-lcov exit status: $status"
  contains "$output" "Coverage:" || fail "quiet summary missing"
  if contains "$output" "Uncovered"; then
    fail "quiet mode printed the table"
  fi
  [ ! -f "$(fixture_dir basic)/coverage/lcov.info" ] || fail "--no-lcov still wrote lcov"

  set +e
  output="$(run_cli basic --exclude 'src/*' 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 2 ] || fail "exclude-all expected exit 2, got $status"
  pass "flags"
}

check_path_deps() {
  clean_coverage path_dep
  local output status
  set +e
  output="$(run_cli path_dep 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] || { fail "path deps: expected exit 0, got $status"; printf '%s\n' "$output"; return; }
  local lcov
  lcov="$(cat "$(fixture_dir path_dep)/coverage/lcov.info")"
  contains "$lcov" "SF:../path_dep_shared/src/shared.gleam" \
    || { fail "path deps: dependency source missing"; printf '%s\n' "$lcov"; return; }
  contains "$lcov" "FN:1,increment/1" || fail "path deps: dependency function missing"
  contains "$lcov" "FNDA:1,increment/1" || fail "path deps: dependency call count"
  contains "$lcov" "DA:2,1" || fail "path deps: dependency line missing"

  clean_coverage path_dep
  output="$(run_cli path_dep --no-path-deps 2>&1)"
  lcov="$(cat "$(fixture_dir path_dep)/coverage/lcov.info")"
  case "$lcov" in
    *"path_dep_shared"*) fail "path deps: --no-path-deps still included dependency" ;;
  esac

  clean_coverage path_dep
  output="$(run_cli path_dep --no-path-deps --include-dep ../path_dep_shared 2>&1)"
  lcov="$(cat "$(fixture_dir path_dep)/coverage/lcov.info")"
  contains "$lcov" "SF:../path_dep_shared/src/shared.gleam" \
    || fail "path deps: explicit include missing"

  set +e
  output="$(run_cli path_dep --include-dep missing 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 2 ] || fail "path deps: missing include expected exit 2, got $status"
  pass "path dependency coverage"
}

check_no_build() {
  clean_coverage basic
  set +e
  run_cli basic --no-build >/dev/null 2>&1
  local status=$?
  set -e
  [ "$status" -eq 0 ] || fail "no-build: expected exit 0, got $status"
  pass "no-build"
}

check_basic
check_minimum
check_failing_tests
check_build_failure
check_no_tests
check_nested
check_eunit_fallback
check_stateful_escript
check_stateful_gleam_run
check_profiler
check_self_time
check_js_coverage
check_flags
check_path_deps
check_no_build

if [ "$failed" -ne 0 ]; then
  printf '\nintegration checks failed\n' >&2
  exit 1
fi
printf '\nall integration checks passed\n'
