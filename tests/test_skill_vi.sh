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
assert_contains "$body" "--panel" "documents --panel flag"
assert_contains "$body" "--render" "documents --render flag"
assert_contains "$body" "--output" "documents --output flag"
assert_contains "$body" "render.sh" "calls render.sh for --render"
assert_contains "$body" "4–7" "states the 4-7 branch guardrail"
assert_contains "$body" "WebFetch" "documents WebFetch for URL input"
assert_contains "$body" "URL" "documents URL as an input type"

# The skill must instruct Vietnamese output, otherwise it is just /mindmap.
assert_contains "$body" "bằng tiếng Việt" "mandates Vietnamese output"

# The vi render pipeline must stay byte-identical to the en one (no drift): both
# skills share the renderer, so a fix applied to one must land in both.
for script in render.sh balanced-layout.js balance-html.mjs degrade-rich.mjs; do
  EN="$here/../skills/mindmap/scripts/$script"
  VI="$here/../skills/mindmap-vi/scripts/$script"
  if cmp -s "$EN" "$VI"; then identical=yes; else identical=no; fi
  assert_eq "yes" "$identical" "vi $script is byte-identical to en $script"
done
VI="$here/../skills/mindmap-vi/scripts/render.sh"

# render.sh must stay executable so `bash <path>` and direct exec both work.
[ -x "$VI" ] && execbit=yes || execbit=no
assert_eq "yes" "$execbit" "vi render.sh is executable"

# --panel must be a real port, not just a flag in the header: the vi skill needs
# its own translated panel reference, and that reference must mandate Vietnamese
# nodes (the en prompts would otherwise produce an English map).
assert_contains "$body" "references/judge-panel.md" "points --panel at the judge-panel reference"
VI_PANEL="$here/../skills/mindmap-vi/references/judge-panel.md"
[ -f "$VI_PANEL" ] && panel=yes || panel=no
assert_eq "yes" "$panel" "vi judge-panel.md reference exists"
panel_body="$(cat "$VI_PANEL" 2>/dev/null)"
assert_contains "$panel_body" "bằng tiếng Việt" "vi panel prompts mandate Vietnamese nodes"
if cmp -s "$here/../skills/mindmap/references/judge-panel.md" "$VI_PANEL"; then copy=yes; else copy=no; fi
assert_eq "no" "$copy" "vi judge-panel.md is translated, not a copy of the en one"

finish
