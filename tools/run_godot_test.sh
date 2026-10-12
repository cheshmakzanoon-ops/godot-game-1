#!/usr/bin/env bash
# Linux CI/local test wrapper: a fresh user-data directory, explicit timeout,
# and failures for engine errors even when Godot returns process exit code zero.
set -euo pipefail
script="${1:?Pass a res://tests/name.gd test script}"
[[ "$script" =~ ^res://tests/[a-z_]+\.gd$ ]] || { echo 'Invalid test script' >&2; exit 2; }
[[ "$(uname -s)" == Linux ]] || { echo 'This isolated runner targets Linux.' >&2; exit 2; }
userdata=$(mktemp -d)
trap 'rm -rf "$userdata"' EXIT
mkdir -p build/engine-evidence
log="build/engine-evidence/$(basename "$script" .gd).log"
status=0
XDG_DATA_HOME="$userdata" timeout 150 godot --headless --path . --script "$script" >"$log" 2>&1 || status=$?
cat "$log"
[[ "$status" -eq 0 ]] || exit "$status"
if grep -Eq 'SCRIPT ERROR:|^ERROR:|ObjectDB.*leaked at exit|instance(s)? (was|were) leaked at exit' "$log"; then
  echo "ENGINE_TEST_FAILED: $script emitted an engine error or leaked objects" >&2
  exit 1
fi
