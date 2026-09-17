#!/usr/bin/env bash
# Tests for render.sh. Run: bash test_render.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/lib.sh"
RENDER="$here/../skills/mindmap/scripts/render.sh"
FIXTURE="$here/fixtures/sample.mindmap.md"

# Clean up all temp dirs created below, even if a check fails.
_tmpdirs=()
trap 'rm -rf "${_tmpdirs[@]}"' EXIT

# Case 1: no argument -> usage error, exit 1
bash "$RENDER" >/dev/null 2>&1; rc=$?
assert_eq 1 "$rc" "no arg exits 1 (usage)"

# Case 2: missing .md file -> exit 2
bash "$RENDER" "$here/fixtures/does-not-exist.md" >/dev/null 2>&1; rc=$?
assert_eq 2 "$rc" "missing md exits 2"

# Case 3: npx not on PATH -> exit 3, prints manual command to stderr
# Note: launch via "$BASH" (absolute path) so emptying PATH hides npx from the
# child without also making the bash interpreter itself unresolvable.
empty="$(mktemp -d)"; _tmpdirs+=("$empty")
err="$(PATH="$empty" "$BASH" "$RENDER" "$FIXTURE" 2>&1 >/dev/null)"; rc=$?
assert_eq 3 "$rc" "missing npx exits 3"
assert_contains "$err" "markmap-cli" "missing npx prints manual command"

# Build a fake npx that touches the file named after -o, so we never hit the network.
fakebin="$(mktemp -d)"; _tmpdirs+=("$fakebin")
cat > "$fakebin/npx" <<'FAKE'
#!/usr/bin/env bash
echo "npx noise on stdout that must not leak"
out=""; prev=""
for a in "$@"; do
  [ "$prev" = "-o" ] && out="$a"
  prev="$a"
done
[ -n "$out" ] && printf '<html></html>' > "$out"
exit 0
FAKE
chmod +x "$fakebin/npx"

# Case 4: success -> exit 0, stdout is the derived .html path, file created
work="$(mktemp -d)"; _tmpdirs+=("$work")
cp "$FIXTURE" "$work/doc.mindmap.md"
out="$(PATH="$fakebin:$PATH" bash "$RENDER" "$work/doc.mindmap.md")"; rc=$?
assert_eq 0 "$rc" "success exits 0"
assert_eq "$work/doc.mindmap.html" "$out" "derives .html path from .md"
[ -f "$work/doc.mindmap.html" ] && created=yes || created=no
assert_eq "yes" "$created" "html file is created"

# Case 5: explicit output path is honored
out2="$(PATH="$fakebin:$PATH" bash "$RENDER" "$work/doc.mindmap.md" "$work/custom.html")"
assert_eq "$work/custom.html" "$out2" "honors explicit html path"

# Build a fake npx that FAILS, to exercise the exit-4 (render failed) branch.
failbin="$(mktemp -d)"; _tmpdirs+=("$failbin")
cat > "$failbin/npx" <<'FAKE'
#!/usr/bin/env bash
echo "boom" >&2
exit 1
FAKE
chmod +x "$failbin/npx"

# Case 6: npx present but markmap-cli fails -> exit 4
PATH="$failbin:$PATH" bash "$RENDER" "$work/doc.mindmap.md" >/dev/null 2>&1; rc=$?
assert_eq 4 "$rc" "render failure exits 4"

# Case 7: HTML without a markmap-view script tag (the fake npx above emits bare
# <html></html>) cannot be patched -> warn on stderr, but still succeed.
warn="$(PATH="$fakebin:$PATH" bash "$RENDER" "$work/doc.mindmap.md" "$work/nopatch.html" 2>&1 >/dev/null)"; rc=$?
assert_eq 0 "$rc" "unpatchable html still exits 0"
assert_contains "$warn" "balanced layout not applied" "warns when layout patch cannot be applied"

# Build a fake npx that emits markmap-cli-shaped HTML, so the bilateral-layout
# patch has its anchor (the markmap-view script tag) to attach to.
mmbin="$(mktemp -d)"; _tmpdirs+=("$mmbin")
cat > "$mmbin/npx" <<'FAKE'
#!/usr/bin/env bash
out=""; prev=""
for a in "$@"; do
  [ "$prev" = "-o" ] && out="$a"
  prev="$a"
done
cat > "$out" <<'HTML'
<html><head><title>Markmap</title></head><body><svg id="mindmap"></svg>
<script src="https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/markmap-view@0.18.12/dist/browser/index.js"></script>
<script>window.mm = markmap.Markmap.create("svg#mindmap", null, {});</script>
</body></html>
HTML
exit 0
FAKE
chmod +x "$mmbin/npx"

# Case 8: the patch is inlined, and inlined BEFORE the Markmap.create() call —
# patching the prototype after create() would leave the map one-sided.
PATH="$mmbin:$PATH" bash "$RENDER" "$work/doc.mindmap.md" "$work/patched.html" >/dev/null 2>&1
patched="$(cat "$work/patched.html")"
assert_contains "$patched" "balanced-layout.js" "inlines the balanced-layout patch"
assert_contains "$patched" "markmap-mirrored" "inlines the patch body, not just a marker"
marker_at="$(awk '/balanced-layout.js/ {print NR; exit}' "$work/patched.html")"
create_at="$(awk '/Markmap.create/ {print NR; exit}' "$work/patched.html")"
[ -n "$marker_at" ] && [ -n "$create_at" ] && [ "$marker_at" -lt "$create_at" ] && before=yes || before=no
assert_eq "yes" "$before" "patch is inlined before Markmap.create"

# Case 9: re-rendering over an already patched file must not stack copies.
PATH="$mmbin:$PATH" bash "$RENDER" "$work/doc.mindmap.md" "$work/patched.html" >/dev/null 2>&1
node "$here/../skills/mindmap/scripts/balance-html.mjs" "$work/patched.html"
copies="$(grep -c '/\* balanced-layout.js \*/' "$work/patched.html")"
assert_eq 1 "$copies" "injection is idempotent"

# Case 10: the browser patch must be syntactically valid; it is inlined verbatim
# into every rendered .html, so a parse error would break the whole page.
node --check "$here/../skills/mindmap/scripts/balanced-layout.js" 2>/dev/null; rc=$?
assert_eq 0 "$rc" "balanced-layout.js parses"

# Case 11: skills are installed as a symlink (~/.agents/skills/<name> -> this
# repo), so render.sh reaches balance-html.mjs through a symlinked path. Node
# resolves import.meta.url to the realpath, so a naive main-guard comparison
# silently skips patching and the HTML stays one-sided.
linkroot="$(mktemp -d)"; _tmpdirs+=("$linkroot")
ln -s "$here/../skills/mindmap" "$linkroot/mindmap"
PATH="$mmbin:$PATH" bash "$linkroot/mindmap/scripts/render.sh" \
  "$work/doc.mindmap.md" "$work/symlinked.html" >/dev/null 2>&1
assert_contains "$(cat "$work/symlinked.html")" "balanced-layout.js" \
  "patches html when invoked through a symlinked skill dir"

# Case 12: markmap-cli hardcodes <title>Markmap</title>, so every open map looks
# identical in the tab bar. The render must substitute the map's own title.
titled="$(cat "$work/patched.html")"
assert_contains "$titled" "<title>Sample</title>" "tab title comes from frontmatter title"
[ "${titled#*<title>Markmap</title>}" = "$titled" ] && gone=yes || gone=no
assert_eq "yes" "$gone" "hardcoded Markmap title is replaced"

# Case 13: no frontmatter title -> fall back to the H1, as plain text: a tab bar
# renders no markdown, and & / < would break the HTML if passed through raw.
cat > "$work/plain.mindmap.md" <<'MD'
# **Chiến lược** & `AI`

## Branch
- point
MD
PATH="$mmbin:$PATH" bash "$RENDER" "$work/plain.mindmap.md" >/dev/null 2>&1
assert_contains "$(cat "$work/plain.mindmap.html")" "<title>Chiến lược &amp; AI</title>" \
  "falls back to the H1 as escaped plain text"

# Case 14: the title patch is best-effort — an unreadable .md must still leave a
# layout-patched .html behind, never fail the render.
PATH="$mmbin:$PATH" bash "$RENDER" "$work/doc.mindmap.md" "$work/orphan.html" >/dev/null 2>&1
node "$here/../skills/mindmap/scripts/balance-html.mjs" "$work/orphan.html" 2>/dev/null; rc=$?
assert_eq 0 "$rc" "missing markmap source is not fatal"
assert_contains "$(cat "$work/orphan.html")" "balanced-layout.js" \
  "keeps the layout patch when the title source is missing"

finish
