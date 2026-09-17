#!/usr/bin/env node
// balance-html.mjs — post-process markmap-cli HTML output.
//
// Two patches, both best-effort and idempotent:
//
// 1. Balanced layout — markmap-cli emits a one-sided (right-growing) mindmap.
//    Inline the bilateral-layout patch right after the markmap-view bundle, so
//    it runs before the inline script that calls Markmap.create(). The patch is
//    inlined, not linked, to keep the .html a single self-contained file.
// 2. Page title — markmap-cli hardcodes <title>Markmap</title>, so every
//    rendered map looks identical in the browser tab bar. Replace it with the
//    map's own title (frontmatter `title:`, else the H1).
//
// Usage: node balance-html.mjs <html-path> [md-path]
//   md-path defaults to <html-path> with .html swapped for .md. A missing or
//   unreadable .md only skips the title patch; it is never fatal.
// Exit: 0 ok (patched, or already patched) | 1 usage | 2 html/patch not found
//       | 6 markmap-view script tag not found (title patch still applied)
import { readFileSync, writeFileSync, realpathSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const MARKER = 'balanced-layout.js';
const ANCHOR = /<script\b[^>]*\bsrc=["'][^"']*markmap-view[^"']*["'][^>]*>\s*<\/script>/i;
const TITLE_TAG = /<title\b[^>]*>[\s\S]*?<\/title>/i;
const HEAD_OPEN = /<head\b[^>]*>/i;

function balanceHtml(html, patch) {
  if (html.includes(MARKER)) return html;
  const anchor = html.match(ANCHOR);
  if (!anchor) return null;
  const tag = `${anchor[0]}\n<script>/* ${MARKER} */\n${patch}</script>`;
  return html.slice(0, anchor.index) + tag + html.slice(anchor.index + anchor[0].length);
}

// Plain-text label for a node/title line: markmap renders inline markdown, a
// browser tab cannot, so `**Foo**` / `` `bar` `` / `[x](y)` would leak syntax.
function plainText(s) {
  return s
    .replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/[`*_]/g, '')
    .trim();
}

// Frontmatter `title:` wins (the skill always writes it); fall back to the H1
// so a hand-written .md without frontmatter still gets a real tab title.
function mindmapTitle(md) {
  const fm = md.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (fm) {
    // Anchored at column 0 on purpose: nested keys (markmap: -> title:) are
    // indented and must not be picked up.
    const key = fm[1].match(/^title:[ \t]*(\S.*)$/m);
    if (key) {
      const raw = key[1].trim().replace(/^(['"])([\s\S]*)\1$/, '$2');
      const title = plainText(raw);
      if (title) return title;
    }
  }
  const h1 = (fm ? md.slice(fm[0].length) : md).match(/^#[ \t]+(\S.*)$/m);
  if (h1) {
    const title = plainText(h1[1]);
    if (title) return title;
  }
  return null;
}

function setHtmlTitle(html, title) {
  const esc = title.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const tag = `<title>${esc}</title>`;
  if (TITLE_TAG.test(html)) return html.replace(TITLE_TAG, tag);
  const head = html.match(HEAD_OPEN);
  if (head) return html.slice(0, head.index + head[0].length) + tag + html.slice(head.index + head[0].length);
  return html;
}

export { balanceHtml, mindmapTitle, setHtmlTitle };

// Skills are normally installed as a symlink (~/.agents/skills/<name> ->
// this repo) and render.sh invokes this script by that symlinked path. Node
// resolves import.meta.url to the realpath, so a plain === never matches and
// the CLI becomes a silent no-op that leaves the HTML one-sided. Compare
// realpaths instead.
const realOrSelf = (p) => { try { return realpathSync(p); } catch { return p; } };
if (process.argv[1] && realOrSelf(fileURLToPath(import.meta.url)) === realOrSelf(process.argv[1])) {
  const htmlPath = process.argv[2];
  if (!htmlPath) {
    process.stderr.write('usage: balance-html.mjs <html-path> [md-path]\n');
    process.exit(1);
  }
  const mdPath = process.argv[3]
    || (/\.html?$/i.test(htmlPath) ? htmlPath.replace(/\.html?$/i, '.md') : null);
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
  let out = html;
  if (mdPath) {
    let title = null;
    try {
      title = mindmapTitle(readFileSync(mdPath, 'utf8'));
    } catch {
      process.stderr.write(`warning: no markmap source at ${mdPath}; tab title left as-is.\n`);
    }
    if (title) out = setHtmlTitle(out, title);
  }
  const result = balanceHtml(out, patch);
  if (result === null) {
    // The title patch is independent of the layout anchor: keep it, then report
    // the layout failure so render.sh can warn.
    if (out !== html) writeFileSync(htmlPath, out, 'utf8');
    process.stderr.write(`error: no markmap-view script tag in ${htmlPath}\n`);
    process.exit(6);
  }
  if (result !== html) writeFileSync(htmlPath, result, 'utf8');
}
