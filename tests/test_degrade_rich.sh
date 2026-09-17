#!/usr/bin/env bash
# Tests for degrade-rich.mjs (the --panel poster path). Run: bash test_degrade_rich.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/lib.sh"
DEGRADE="$here/../skills/mindmap/scripts/degrade-rich.mjs"

_tmpdirs=()
trap 'rm -rf "${_tmpdirs[@]}"' EXIT

# Case 1: the unit tests next to the script only run if the harness runs them —
# run_tests.sh collects test_*.sh only, so wire them in here.
node --test "$here/../skills/mindmap/scripts/degrade-rich.test.mjs" >/dev/null 2>&1; rc=$?
assert_eq 0 "$rc" "degrade-rich unit tests pass"

work="$(mktemp -d)"; _tmpdirs+=("$work")
cat > "$work/rich.md" <<'MD'
## Kết quả
| Benchmark | Trước | Sau |
| --- | --- | --- |
| SWE Pro | 46.0 | 51.5 |

## Việc cần làm
- [ ] mở mã nguồn
MD

# Case 2: CLI writes the degraded file and prints its path (poster path input).
out="$(node "$DEGRADE" "$work/rich.md" "$work/poster.md")"; rc=$?
assert_eq 0 "$rc" "cli exits 0 on a rich .md"
assert_eq "$work/poster.md" "$out" "cli prints the output path"
degraded="$(cat "$work/poster.md")"
assert_contains "$degraded" "- SWE Pro · 46.0 · 51.5" "table row becomes a bullet"
assert_contains "$degraded" "- mở mã nguồn" "checkbox becomes a bullet"

# Case 3: skills are installed as a symlink (~/.agents/skills/<name> -> this
# repo), so the skill invokes this script through a symlinked path. Node resolves
# import.meta.url to the realpath, so a naive main-guard comparison makes the CLI
# a silent no-op and the poster keeps unparseable rich nodes.
linkroot="$(mktemp -d)"; _tmpdirs+=("$linkroot")
ln -s "$here/../skills/mindmap" "$linkroot/mindmap"
linked="$(node "$linkroot/mindmap/scripts/degrade-rich.mjs" "$work/rich.md" "$work/linked.md" 2>/dev/null)"
assert_eq "$work/linked.md" "$linked" "cli runs when invoked through a symlinked skill dir"
assert_contains "$(cat "$work/linked.md" 2>/dev/null)" "- SWE Pro" "symlinked run degrades the table"

# Case 4: documented error contract — missing file and empty input are distinct.
node "$DEGRADE" "$work/nope.md" >/dev/null 2>&1; rc=$?
assert_eq 2 "$rc" "missing input exits 2"
: > "$work/empty.md"
node "$DEGRADE" "$work/empty.md" >/dev/null 2>&1; rc=$?
assert_eq 5 "$rc" "empty input exits 5"

finish
