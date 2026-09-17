#!/usr/bin/env bash
# render.sh — render a Markmap .md to standalone interactive HTML.
# Usage: render.sh <md-path> [html-path]
# Exit codes: 0 ok | 1 usage | 2 md not found | 3 npx missing | 4 render failed
set -euo pipefail

md="${1:-}"
if [ -z "$md" ]; then
  echo "usage: render.sh <md-path> [html-path]" >&2
  exit 1
fi

if [ ! -f "$md" ]; then
  echo "error: markmap file not found: $md" >&2
  exit 2
fi

html="${2:-}"
if [ -z "$html" ]; then
  # swap trailing .md for .html (handles foo.mindmap.md -> foo.mindmap.html)
  html="${md%.md}.html"
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx not found; the .md is safe but HTML was not rendered." >&2
  echo "to render manually, install Node.js then run:" >&2
  echo "  npx --yes markmap-cli \"$md\" -o \"$html\" --no-open" >&2
  exit 3
fi

# send npx chatter to stderr; stdout must stay just the html path (callers capture it)
if ! npx --yes markmap-cli "$md" -o "$html" --no-open >&2; then
  echo "error: markmap-cli failed; the .md is safe but HTML was not rendered." >&2
  exit 4
fi

# markmap-cli emits a right-only tree, which wastes the whole left half of the
# viewport and shrinks the text, and it hardcodes <title>Markmap</title> so every
# map looks the same in the tab bar. Inline the bilateral-layout patch and set the
# real title. Best-effort: a one-sided .html is still a valid deliverable, so
# never fail the render here.
balance="$(cd "$(dirname "$0")" && pwd)/balance-html.mjs"
if [ -f "$balance" ] && command -v node >/dev/null 2>&1; then
  if ! node "$balance" "$html" "$md" >/dev/null; then
    echo "warning: balanced layout not applied; HTML keeps markmap's one-sided layout." >&2
  fi
else
  echo "warning: balanced layout skipped (needs Node.js and balance-html.mjs)." >&2
fi

echo "$html"
