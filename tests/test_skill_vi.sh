#!/usr/bin/env bash
# Validates the Vietnamese skill (mindmap-vi). Run: bash test_skill_vi.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/lib.sh"
SKILL="$here/../skills/mindmap-vi/SKILL.md"
body="$(cat "$SKILL" 2>/dev/null)"

[ -f "$SKILL" ] && exists=yes || exists=no
assert_eq "yes" "$exists" "mindmap-vi SKILL.md exists"

first="$(head -n 1 "$SKILL" 2>/dev/null)"
assert_eq "---" "$first" "starts with frontmatter delimiter"

assert_contains "$body" "name: mindmap-vi" "declares name: mindmap-vi"
assert_contains "$body" "user-invocable: true" "is user-invocable"
assert_contains "$body" "allowed-tools: Bash, Read, Write, Glob, WebFetch" "declares allowed-tools"
assert_contains "$body" "/mindmap-vi" "documents the /mindmap-vi trigger"

# Required sections (Vietnamese headers)
assert_contains "$body" "## Workflow" "has Workflow section"
assert_contains "$body" "## Định dạng Markmap" "has Markmap Format section"
assert_contains "$body" "colorFreezeLevel: 2" "format keeps frontmatter defaults"
assert_contains "$body" "## Ví dụ minh hoạ" "has Worked Example section"
assert_contains "$body" ".mindmap.md" "documents default output filename"
assert_contains "$body" "--render" "documents --render flag"
assert_contains "$body" "--output" "documents --output flag"
assert_contains "$body" "render.sh" "calls render.sh for --render"
assert_contains "$body" "4–7" "states the 4-7 branch guardrail"
assert_contains "$body" "WebFetch" "documents WebFetch for URL input"
assert_contains "$body" "URL" "documents URL as an input type"

# The skill must instruct Vietnamese output, otherwise it is just /mindmap.
assert_contains "$body" "bằng tiếng Việt" "mandates Vietnamese output"

# The vi render.sh must stay byte-identical to the en one (no drift).
EN="$here/../skills/mindmap/scripts/render.sh"
VI="$here/../skills/mindmap-vi/scripts/render.sh"
if cmp -s "$EN" "$VI"; then identical=yes; else identical=no; fi
assert_eq "yes" "$identical" "vi render.sh is byte-identical to en render.sh"

# render.sh must stay executable so `bash <path>` and direct exec both work.
[ -x "$VI" ] && execbit=yes || execbit=no
assert_eq "yes" "$execbit" "vi render.sh is executable"

finish
