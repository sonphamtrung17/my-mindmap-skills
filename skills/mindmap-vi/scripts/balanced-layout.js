/* balanced-layout.js — bilateral (two-sided) layout for markmap.
 *
 * markmap grows the tree to the right only: the root sits on the left edge and
 * every branch stacks downward. A map with many branches is therefore tall and
 * narrow, fit() ends up height-constrained, and the whole left half of the
 * viewport stays empty while the content shrinks to an unreadable scale.
 *
 * This patch splits the root's branches into a right group and a left group
 * (contiguous, cut where the two halves are closest in height), stacks each
 * group vertically on its own, and mirrors the left group across the root's
 * horizontal centre. Result: ~half the height, ~double the width, balanced
 * margins, much larger scale.
 *
 * Node transforms, link paths and fit() all derive from `node.state.rect`, so
 * rewriting rects inside _relayout() is enough for the geometry. renderData()
 * is post-processed only to flip what is direction-dependent: link endpoints
 * (parent's left edge -> child's right edge) and the fold toggle circle.
 *
 * Patches Markmap.prototype rather than subclassing: the static create() does
 * `new <internal binding>(...)`, so replacing window.markmap.Markmap would
 * never reach the instance the page actually builds.
 *
 * No-op if window.markmap, d3, or the patched methods are absent, so a markmap
 * version bump degrades to stock one-sided layout instead of a broken page.
 */
(function () {
  var mk = window.markmap;
  var d3 = window.d3;
  if (!mk || !mk.Markmap || !d3 || !d3.linkHorizontal) return;

  var proto = mk.Markmap.prototype;
  if (typeof proto._relayout !== 'function') return;
  if (typeof proto.renderData !== 'function') return;

  var linkShape = d3.linkHorizontal();
  var MIRROR_CLASS = 'markmap-mirrored';

  // No text-align:right for mirrored nodes on purpose: markmap sizes each node
  // from the content div's scrollWidth, and right-aligned overflow grows
  // leftwards where scrollWidth cannot see it — the node would be measured too
  // narrow on the next _relayout() and clip its own text.

  // Visible nodes only: a folded node hides its subtree, and markmap's layout
  // leaves stale rects on hidden nodes.
  function collect(node, out) {
    out.push(node);
    if (!node.payload || !node.payload.fold) {
      var kids = node.children || [];
      for (var i = 0; i < kids.length; i++) collect(kids[i], out);
    }
    return out;
  }

  function measure(nodes) {
    var top = Infinity;
    var bottom = -Infinity;
    for (var i = 0; i < nodes.length; i++) {
      var r = nodes[i].state.rect;
      if (r.y < top) top = r.y;
      if (r.y + r.height > bottom) bottom = r.y + r.height;
    }
    return { nodes: nodes, top: top, height: bottom - top };
  }

  var baseRelayout = proto._relayout;
  var baseRenderData = proto.renderData;

  proto._relayout = function () {
    baseRelayout.call(this);

    var root = this.state.data;
    if (!root || (root.payload && root.payload.fold)) return;
    var kids = root.children || [];
    if (kids.length < 2) return;

    var groups = kids.map(function (kid) {
      return measure(collect(kid, []));
    });

    // Vertical gap between branches of different parents, matching the spacing
    // markmap's own layout uses for that case.
    var gap = (this.options.spacingVertical || 0) * 2;

    var total = 0;
    groups.forEach(function (g) {
      total += g.height + gap;
    });

    // Contiguous split keeps the document's top-to-bottom reading order on each
    // side; cut where |right - left| is smallest.
    var cut = 1;
    var bestDiff = Infinity;
    var run = 0;
    for (var i = 1; i < groups.length; i++) {
      run += groups[i - 1].height + gap;
      var diff = Math.abs(total - 2 * run);
      if (diff < bestDiff) {
        bestDiff = diff;
        cut = i;
      }
    }

    var rootRect = root.state.rect;
    var axis = rootRect.x + rootRect.width / 2;
    var centerY = rootRect.y + rootRect.height / 2;

    function place(side, mirror) {
      var height = gap * Math.max(0, side.length - 1);
      side.forEach(function (g) {
        height += g.height;
      });
      var cursor = centerY - height / 2;
      side.forEach(function (g) {
        var dy = cursor - g.top;
        g.nodes.forEach(function (node) {
          var r = node.state.rect;
          r.y += dy;
          if (mirror) r.x = 2 * axis - r.x - r.width;
          node.state.mirrored = mirror;
        });
        cursor += g.height + gap;
      });
    }

    place(groups.slice(0, cut), false);
    place(groups.slice(cut), true);

    var all = [root];
    groups.forEach(function (g) {
      all = all.concat(g.nodes);
    });
    var x1 = Infinity;
    var y1 = Infinity;
    var x2 = -Infinity;
    var y2 = -Infinity;
    all.forEach(function (node) {
      var r = node.state.rect;
      if (r.x < x1) x1 = r.x;
      if (r.y < y1) y1 = r.y;
      if (r.x + r.width > x2) x2 = r.x + r.width;
      if (r.y + r.height > y2) y2 = r.y + r.height;
    });
    this.state.rect = { x1: x1, y1: y1, x2: x2, y2: y2 };
  };

  proto.renderData = async function (node) {
    await baseRenderData.call(this, node);

    var lineWidth = this.options.lineWidth;
    var color = this.options.color;
    var root = this.state.data;
    if (!root) return;

    // Folded-away nodes and links are still in the DOM, mid-exit-transition,
    // and that transition is what removes them. Touching them — above all
    // starting a transition of our own — cancels the removal and leaves orphan
    // branches and link stubs behind, so restrict every fixup to live data.
    var live = new Set(collect(root, []));

    // cx is set outside markmap's transition, so plain attr() is enough.
    this.g
      .selectAll('g.markmap-node')
      .filter(function (d) {
        return live.has(d);
      })
      .each(function (d) {
        var mirrored = !!(d.state && d.state.mirrored);
        var sel = d3.select(this);
        sel.classed(MIRROR_CLASS, mirrored);
        sel.selectAll('circle').attr('cx', mirrored ? 0 : d.state.rect.width);
      });

    // `d` IS transitioned by markmap towards right-only endpoints; replace that
    // transition wholesale (stroke and width included) so nothing animates to a
    // stale path.
    var links = this.g.selectAll('path.markmap-link').filter(function (l) {
      return live.has(l.source) && live.has(l.target);
    });
    this.transition(links)
      .attr('stroke', function (l) {
        return color(l.target);
      })
      .attr('stroke-width', function (l) {
        return lineWidth(l.target);
      })
      .attr('d', function (l) {
        var s = l.source.state;
        var t = l.target.state;
        // The side is the TARGET's: a mirrored child hangs off its parent's
        // left edge, whatever side the parent itself is on. Keying the exit
        // edge off the source instead makes every left-hand link leave the
        // root's right edge and sweep back across the root's own label.
        var sx = t.mirrored ? s.rect.x : s.rect.x + s.rect.width;
        var tx = t.mirrored ? t.rect.x + t.rect.width : t.rect.x;
        return linkShape({
          source: [sx, s.rect.y + s.rect.height + lineWidth(l.source) / 2],
          target: [tx, t.rect.y + t.rect.height + lineWidth(l.target) / 2],
        });
      });
  };
})();
