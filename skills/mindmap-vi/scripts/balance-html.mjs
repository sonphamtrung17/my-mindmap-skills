#!/usr/bin/env node
// balance-html.mjs — inline balanced-layout.js into markmap-cli HTML output.
//
// markmap-cli emits a one-sided (right-growing) mindmap. This inlines the
// bilateral-layout patch right after the markmap-view bundle, so it runs before
// the inline script that calls Markmap.create(). The patch is inlined, not
// linked, to keep the .html a single self-contained file.
//
// Usage: node balance-html.mjs <html-path>
// Exit: 0 ok (patched, or already patched) | 1 usage | 2 file not found
//       | 6 markmap-view script tag not found (nothing was modified)
import { readFileSync, writeFileSync, realpathSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const MARKER = 'balanced-layout.js';
const ANCHOR = /<script\b[^>]*\bsrc=["'][^"']*markmap-view[^"']*["'][^>]*>\s*<\/script>/i;

function balanceHtml(html, patch) {
  if (html.includes(MARKER)) return html;
  const anchor = html.match(ANCHOR);
  if (!anchor) return null;
  const tag = `${anchor[0]}\n<script>/* ${MARKER} */\n${patch}</script>`;
  return html.slice(0, anchor.index) + tag + html.slice(anchor.index + anchor[0].length);
}

export { balanceHtml };

// Skills are normally installed as a symlink (~/.agents/skills/<name> ->
// this repo) and render.sh invokes this script by that symlinked path. Node
// resolves import.meta.url to the realpath, so a plain === never matches and
// the CLI becomes a silent no-op that leaves the HTML one-sided. Compare
// realpaths instead.
const realOrSelf = (p) => { try { return realpathSync(p); } catch { return p; } };
if (process.argv[1] && realOrSelf(fileURLToPath(import.meta.url)) === realOrSelf(process.argv[1])) {
  const htmlPath = process.argv[2];
  if (!htmlPath) {
    process.stderr.write('usage: balance-html.mjs <html-path>\n');
    process.exit(1);
  }
  const patchPath = resolve(dirname(fileURLToPath(import.meta.url)), 'balanced-layout.js');
  let html;
  let patch;
  try {
    html = readFileSync(htmlPath, 'utf8');
    patch = readFileSync(patchPath, 'utf8');
  } catch (err) {
    process.stderr.write(`error: file not found: ${err.path || htmlPath}\n`);
    process.exit(2);
  }
  const result = balanceHtml(html, patch);
  if (result === null) {
    process.stderr.write(`error: no markmap-view script tag in ${htmlPath}\n`);
    process.exit(6);
  }
  writeFileSync(htmlPath, result, 'utf8');
}
