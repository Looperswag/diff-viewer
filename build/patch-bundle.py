#!/usr/bin/env python3
"""
patch-bundle.py — re-apply the diff-viewer post-export fixes to a freshly
exported "dc"-framework bundle.

The app is authored in a separate source project and exported as a single
self-contained HTML bundle (the `__bundler/manifest` + `__bundler/template`
structure). A RAW export is not shippable as `index.html` — it needs four
fixes, applied here. The script is idempotent: re-running on an already-patched
file is a no-op, so "export -> patch-bundle.py -> commit" is always safe.

  1. scroll fix     — the framework wraps the app in block-level <div id="dc-root">
                      and <div class="sc-host"> between
                      body{display:flex;flex-direction:column;height:100vh} and
                      .app-body{flex:1}. Because the wrappers are display:block,
                      flex:1 never gets a bounded height, so <main> can't scroll
                      and the comparison output below 100vh is clipped by
                      body{overflow:hidden}. We inject display:contents to drop
                      the wrappers from the box tree (verified: main scrollHeight
                      4824 > clientHeight 731).
  2. drop tracker   — remove the injected <script src="https://g.alicdn.com/...">.
  3. drop preconnect— strip the Google-Fonts <link rel="preconnect"> hints; all
                      fonts are embedded as blobs, so these are the only would-be
                      network touch. Keeps the tool 100% offline.
  4. decompress     — gunzip any `compressed:true` manifest assets (incl. the app
                      bundle) so the loader never needs DecompressionStream
                      (Safari 16.4+) — keeps it working on older WebKit.

Usage:
  python3 build/patch-bundle.py EXPORT.html              # patch in place
  python3 build/patch-bundle.py EXPORT.html -o index.html
"""
import argparse
import base64
import gzip
import json
import re
import sys

# Guard string proving the scroll fix is already applied (idempotency).
# Must be a substring of the injected <style> below.
FIX_MARK = '#dc-root>.sc-host{display:contents}'

# The two loader statements we inject, run right before the loader parses the
# template. JS_PRECONNECT is a raw string so its regex backslashes survive.
JS_SCROLL = ("template = template.replace('</head>', "
             "'<style>x-dc,#dc-root,#dc-root>.sc-host{display:contents}"
             "helmet{display:none}</style></head>');")
JS_PRECONNECT = r"""template = template.replace(/<link\b[^>]*\brel=["']?preconnect["']?[^>]*>/gi, '');"""

# Anchors. The DOMParser swap line is the most stable point in the loader.
ANCHOR_RE = re.compile(r'^([ \t]*)const doc = new DOMParser\(\)\.parseFromString\(template,', re.M)
ALICDN_RE = re.compile(r'<script[^>]*src="https?://g\.alicdn\.com/[^"]*"[^>]*>\s*</script>')
MANIFEST_TAG = '<script type="__bundler/manifest">'


def patch(html):
    notes = []

    # (1)+(3) inject scroll fix + preconnect strip into the loader.
    if FIX_MARK in html:
        notes.append('scroll fix / preconnect strip: already present, skipped')
    else:
        m = ANCHOR_RE.search(html)
        if not m:
            sys.exit('ERROR: loader anchor (DOMParser line) not found — the export '
                     'format changed; update ANCHOR_RE in patch-bundle.py.')
        indent = m.group(1)
        inject = indent + JS_SCROLL + '\n' + indent + JS_PRECONNECT + '\n'
        html = html[:m.start()] + inject + html[m.start():]
        notes.append('scroll fix + preconnect strip: injected')

    # (2) drop the injected alicdn tracker (its timestamp varies per export).
    html, n = ALICDN_RE.subn('', html)
    notes.append('alicdn tracker: removed %d' % n if n else 'alicdn tracker: none found')

    # (4) decompress any gzip manifest assets.
    lines = html.split('\n')
    try:
        mi = next(i for i, l in enumerate(lines) if l.lstrip().startswith(MANIFEST_TAG))
    except StopIteration:
        sys.exit('ERROR: no __bundler/manifest found — input is not a recognised bundle.')
    manifest = json.loads(lines[mi + 1])
    dec = 0
    for entry in manifest.values():
        if entry.get('compressed'):
            entry['data'] = base64.b64encode(
                gzip.decompress(base64.b64decode(entry['data']))).decode('ascii')
            entry['compressed'] = False
            dec += 1
    if dec:
        serialized = json.dumps(manifest, separators=(',', ':'))
        # The manifest lives inside <script type="__bundler/manifest">…</script>;
        # a literal </script> in its text would close the tag early.
        assert '</script>' not in serialized, 'serialized manifest contains </script>'
        lines[mi + 1] = serialized
        html = '\n'.join(lines)
    notes.append('gzip assets decompressed: %d' % dec)

    return html, notes


def verify(html):
    """Post-conditions — fail loudly rather than write a broken bundle."""
    assert FIX_MARK in html, 'scroll fix missing after patch'
    assert 'g.alicdn.com' not in html, 'alicdn reference still present after patch'
    lines = html.split('\n')
    mi = next(i for i, l in enumerate(lines) if l.lstrip().startswith(MANIFEST_TAG))
    manifest = json.loads(lines[mi + 1])
    assert not any(e.get('compressed') for e in manifest.values()), 'compressed assets remain'


def main():
    ap = argparse.ArgumentParser(
        description='Re-apply diff-viewer post-export fixes to a "dc" bundle (idempotent).')
    ap.add_argument('input', help='freshly exported bundle .html')
    ap.add_argument('-o', '--output', help='output path (default: overwrite input)')
    args = ap.parse_args()

    with open(args.input, encoding='utf-8') as f:
        html = f.read()
    html, notes = patch(html)
    verify(html)
    out = args.output or args.input
    with open(out, 'w', encoding='utf-8') as f:
        f.write(html)

    for note in notes:
        print('  - ' + note)
    print('OK -> %s  (verified: scroll fix present, 0 alicdn refs, 0 compressed assets)' % out)


if __name__ == '__main__':
    main()
