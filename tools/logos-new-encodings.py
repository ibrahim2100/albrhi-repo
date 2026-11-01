#!/usr/bin/env python3
"""`%new(typeencoding)` -- written explicitly, and proved to be what Logos would have computed.

    python3 tools/logos-new-encodings.py --apply tweaks/instagram/src/Foo.x ...   # bare %new -> %new(enc)
    python3 tools/logos-new-encodings.py --check <file-or-dir> ...                # every %new(enc) equals Logos' own

Why this exists. The `ios-logos-tweak` skill (PoomSmart, MIT; `.claude/skills/ios-logos-tweak/`) says to
always write `%new(typeencoding)`: a bare `%new` makes Logos *generate* the encoding at run time out of
the declaration, with `@encode(T)` for every parameter that is not an object pointer. The generated form is
correct by construction; an encoding typed by hand is a claim. So this tool does not trust either: it runs
Logos itself on the file as written and again with every `%new(...)` reduced to a bare `%new`, evaluates what
each form would pass to `class_addMethod`, and compares them method by method (group, class, selector).
`--apply` fills in the bare ones from Logos' own answer; `--check` is the proof afterwards and can be
re-run whenever a signature changes (CLAUDE.md §4.8).

`@encode(T)` is evaluated from a fixed table of what appears in this repository (arm64 iOS): BOOL is `B`,
NSInteger `q`, every `Foo *` here is an object (`@`). A type the table does not know stops the tool rather
than guessing -- add it to TYPES with its real encoding.

Needs Logos (`$THEOS/vendor/logos/bin/logos.pl`).
"""
import os
import re
import subprocess
import sys

THEOS = os.environ.get('THEOS') or os.path.expanduser('~/theos')
LOGOS = os.path.join(THEOS, 'vendor', 'logos', 'bin', 'logos.pl')

# arm64 iOS. Object pointers are handled by the rule below, not listed.
TYPES = {
    'BOOL': 'B', 'bool': 'B', 'NSInteger': 'q', 'NSUInteger': 'Q', 'CGFloat': 'd',
    'double': 'd', 'float': 'f', 'int': 'i', 'unsigned int': 'I', 'long long': 'q',
    'unsigned long long': 'Q', 'SEL': ':', 'Class': '#', 'id': '@',
}

BLOCK = re.compile(
    r'\{ (?:char _typeEncoding\[1024\]; unsigned int i = 0; (?P<chain>.*?)_typeEncoding\[i\] = \'\\0\'; '
    r'|const char \*_typeEncoding = "(?P<lit>[^"]*)"; )'
    r'class_addMethod\(_logos_class\$(?P<group>\w+)\$(?P<cls>\w+), @selector\((?P<sel>[^)]*)\)')
CHAR = re.compile(r"_typeEncoding\[i\] = '(.)'; i \+= 1;")
MEMCPY = re.compile(r'memcpy\(_typeEncoding \+ i, @encode\((?P<t>[^)]*)\), strlen\(@encode\([^)]*\)\)\); '
                    r'i \+= strlen\(@encode\([^)]*\)\);')


def encode(t):
    t = t.strip()
    if t in TYPES:
        return TYPES[t]
    if t.endswith('*') and not re.search(r'\b(void|char|const|unsigned|int|long|short|float|double)\b', t):
        return '@'
    sys.exit('logos-new-encodings: unknown type @encode(%s) -- add it to TYPES with its real encoding' % t)


def chain_to_enc(chain):
    out, pos = [], 0
    while pos < len(chain):
        m = CHAR.match(chain, pos) or MEMCPY.match(chain, pos)
        if not m:
            sys.exit('logos-new-encodings: cannot read Logos output near: ' + chain[pos:pos + 80])
        out.append(m.group(1) if m.re is CHAR else encode(m.group('t')))
        pos = m.end()
        while pos < len(chain) and chain[pos] == ' ':
            pos += 1
    return ''.join(out)


def logos(text, name):
    """{(group, class, selector): encoding} for every %new in `text`, plus the emission order."""
    ext = os.path.splitext(name)[1] or '.x'
    tmp = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'logos-new-%d%s' % (os.getpid(), ext))
    with open(tmp, 'w') as f:
        f.write(text)
    try:
        p = subprocess.run(['perl', LOGOS, tmp], capture_output=True, text=True)
    finally:
        os.unlink(tmp)
    if p.returncode != 0:
        sys.exit('logos-new-encodings: Logos failed on %s\n%s' % (name, p.stderr[-600:]))
    out, order = {}, []
    for m in BLOCK.finditer(p.stdout):
        enc = m.group('lit') if m.group('lit') is not None else chain_to_enc(m.group('chain'))
        key = (m.group('group'), m.group('cls'), m.group('sel'))
        out[key] = enc
        order.append((key, enc))
    return out, order


# Only a %new that opens a line is a directive; a comment that mentions one is not.
NEW_EXPLICIT = re.compile(r'(?m)^[ \t]*(?P<tok>%new\([^)\n]*\))')
NEW_BARE = re.compile(r'(?m)^[ \t]*(?P<tok>%new)(?!\()(?=[ \t]*(?:\n|-|\+))')


def files_under(paths):
    for p in paths:
        if os.path.isdir(p):
            for root, _, names in os.walk(p):
                for n in sorted(names):
                    if n.endswith(('.x', '.xm')):
                        yield os.path.join(root, n)
        else:
            yield p


def check_one(path):
    text = open(path).read()
    if '%new' not in text:
        return 0, 0
    as_written, _ = logos(text, path)
    stripped, _ = logos(NEW_EXPLICIT.sub(lambda m: m.group(0).replace(m.group('tok'), '%new'), text), path)
    bad = 0
    for key in sorted(set(as_written) | set(stripped)):
        a, b = as_written.get(key), stripped.get(key)
        if a != b:
            bad += 1
            print('%s: %s -- written %r, Logos computes %r' % (path, '/'.join(key), a, b))
    return len(as_written), bad


def apply_one(path):
    text = open(path).read()
    bare = list(NEW_BARE.finditer(text))
    if not bare:
        return 0
    computed, order = logos(text, path)
    # Source order and Logos' emission order agree for the bare ones when each is followed by exactly one
    # class_addMethod; the proof below (--check) is what makes that a fact and not a hope.
    explicit_count = len(NEW_EXPLICIT.findall(text))
    if len(order) != len(bare) + explicit_count:
        sys.exit('%s: %d %%new in source, Logos emitted %d -- fix by hand' % (path, len(bare) + explicit_count, len(order)))
    # Walk both lists in source order; explicit ones are skipped on both sides.
    marks = sorted([(m.start('tok'), m.end('tok'), None) for m in bare] +
                   [(m.start('tok'), m.end('tok'), 'x') for m in NEW_EXPLICIT.finditer(text)])
    out, last, i = [], 0, 0
    for start, end, kind in marks:
        if kind is None:
            out.append(text[last:start])
            out.append('%%new(%s)' % order[i][1])
            last = end
        i += 1
    out.append(text[last:])
    new_text = ''.join(out)
    open(path, 'w').write(new_text)
    return len(bare)


def main():
    args = sys.argv[1:]
    if not args or args[0] not in ('--apply', '--check') or len(args) < 2:
        sys.exit(__doc__)
    mode, paths = args[0], args[1:]
    if not os.path.exists(LOGOS):
        sys.exit('logos-new-encodings: no Logos at %s (set THEOS)' % LOGOS)
    total = bad = 0
    for p in files_under(paths):
        if mode == '--apply':
            n = apply_one(p)
            if n:
                print('%s: %d filled in' % (p, n))
            total += n
        else:
            n, b = check_one(p)
            total, bad = total + n, bad + b
    if mode == '--check':
        print('%d %%new methods checked, %d differ' % (total, bad))
        sys.exit(1 if bad else 0)
    print('%d filled in; now run --check' % total)


if __name__ == '__main__':
    main()
