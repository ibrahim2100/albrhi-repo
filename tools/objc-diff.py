#!/usr/bin/env python3
"""What changed between two builds of an app, among the classes a tweak actually uses.

    python3 tools/objc-diff.py <old> <new> --tweak tweaks/youtube
    python3 tools/objc-diff.py <old> <new> --class '^ML'          # every class matching, no tweak
    python3 tools/objc-diff.py --check <build> --tweak tweaks/youtube   # one build, no "old" needed
    python3 tools/objc-diff.py --selftest

`<old>` and `<new>` are Mach-O executables (dumped on the way, cached by size and mtime) or the
`.json` files `tools/objc-classes.py <binary> --dump <out.json>` writes.

**Why this exists.** CLAUDE.md §4.1 says a class dump is of one app version and an undated dump is a
trap: the follow-badge fix was built from a dump of Instagram 439 while the phone ran 410, and every
tweak here is "tested on" one version and shipped to whichever the phone updates to. A diff of the
*whole* binary is 30,000 classes of noise (YouTube 21.34.3 has 33,263); a diff of **the classes and
selectors our own sources name** is a short list, and it is the list that says whether an app update
broke us before a user does.

`--check <build>` is the one-build form, for the day a new IPA arrives and there is nothing to diff it
against: every `%hook`ed class that the build lacks, and every hooked selector the class (and its
superclasses -- `%orig` reaches up the chain) does not declare. **That second list is rule 4.2 of
CLAUDE.md, automated**: a `%hook` on a method the class does not declare does not politely do nothing,
Logos *adds* it, and an added getter with no original replaces whatever the app resolves for itself.
`%new` methods are additions on purpose and are skipped.

What it reports, most important first:

  1. **Selectors our sources name that are gone or changed encoding** on a class we name -- the thing
     a hook is written against. (A changed encoding is as dangerous as a missing one: TikTok died on a
     hook declared `(double)` whose real encoding was `v48@0:8@16d24^q32@40`.)
  2. **Classes we name that disappeared** from the new build.
  3. **Classes we name that appeared** only in the new build (a feature that arrived, or a rename).
  4. For each class we name, the methods added and removed -- the neighbourhood of a hook.

"Names" means: `%hook X`, `objc_getClass("X")`, `NSClassFromString(@"X")`, any string literal that is a
class in either build; and for selectors `@selector(x:)`, string literals shaped like a selector, and the
selector spelled by a Logos method definition. That is deliberately generous: a class mentioned only in
a comment is reported too, and a report with a few extra lines is better than a hook that was skipped.

It cannot say what a *changed* method now does (that is what a decompiler is for), and it cannot see a
selector our code builds at runtime from pieces.
"""
import hashlib
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(os.path.expanduser('~'), '.cache', 'albrhi-objc')


def load(path):
    """A class table from a dump file, or from a Mach-O (dumped once and cached)."""
    if path.endswith('.json'):
        return json.load(open(path))['classes']
    st = os.stat(path)
    key = hashlib.sha1(('%s|%d|%d' % (os.path.abspath(path), st.st_size, st.st_mtime_ns)).encode()).hexdigest()[:16]
    os.makedirs(CACHE, exist_ok=True)
    cached = os.path.join(CACHE, key + '.json')
    if not os.path.exists(cached):
        print('dumping %s ...' % path, file=sys.stderr)
        subprocess.run([sys.executable, os.path.join(HERE, 'objc-classes.py'), path, '--dump', cached],
                       check=True, stdout=sys.stderr)
    return json.load(open(cached))['classes']


# ── what a tweak's sources name ──────────────────────────────────────────────────────────────

def source_files(root):
    for base, _, files in os.walk(root):
        if '.theos' in base or '/packages' in base or '/tests' in base:
            continue
        for name in files:
            if name.endswith(('.m', '.mm', '.x', '.xm', '.h')):
                yield os.path.join(base, name)


LOGOS_METHOD = re.compile(r'^\s*[-+]\s*\([^)]*\)\s*(.+?)\s*\{?\s*$')


def logos_selector(line):
    """`- (void)setFoo:(id)a withBar:(int)b {` -> `setFoo:withBar:`; None for anything else."""
    m = LOGOS_METHOD.match(line)
    if not m:
        return None
    rest = m.group(1).split('{')[0].strip().rstrip(';').strip()
    parts = re.findall(r'(\w+)\s*:\s*\(', rest)
    if parts:
        return ':'.join(parts) + ':'
    word = re.match(r'(\w+)\s*$', rest)
    return word.group(1) if word else None


def names_in(root):
    """(candidate class names, candidate selectors) with the file each came from."""
    classes, selectors = {}, {}
    for path in source_files(root):
        text = open(path, encoding='utf-8', errors='replace').read()
        rel = os.path.relpath(path, root)

        for m in re.finditer(r'%hook\s+(\w+)|%subclass\s+(\w+)', text):
            classes.setdefault(m.group(1) or m.group(2), rel)
        for m in re.finditer(r'(?:objc_getClass|NSClassFromString)\s*\(\s*@?"(\w+)"', text):
            classes.setdefault(m.group(1), rel)
        for m in re.finditer(r'@"([A-Za-z_]\w{3,})"', text):
            classes.setdefault(m.group(1), rel)       # kept only if a build has such a class
        for m in re.finditer(r'"([A-Za-z_]\w{3,})"', text):
            classes.setdefault(m.group(1), rel)

        for m in re.finditer(r'@selector\(\s*([\w:]+)\s*\)', text):
            selectors.setdefault(m.group(1), rel)
        for m in re.finditer(r'@?"([A-Za-z_]\w*(?::\w*)*:?)"', text):
            selectors.setdefault(m.group(1), rel)
        for line in text.splitlines():
            sel = logos_selector(line)
            if sel:
                selectors.setdefault(sel, rel)
    return classes, selectors


# ── the comparison ───────────────────────────────────────────────────────────────────────────

def diff(old, new, classes, selectors):
    """The four sections, as plain data (so the self-test can assert on it)."""
    named = sorted(c for c in classes if c in old or c in new)
    out = {'selector_changes': [], 'classes_gone': [], 'classes_new': [], 'neighbourhood': {}}

    for cls in named:
        if cls in old and cls not in new:
            out['classes_gone'].append(cls)
            continue
        if cls in new and cls not in old:
            out['classes_new'].append(cls)
            continue

        o, n = old[cls], new[cls]
        added, removed, changed = [], [], []
        for kind, symbol in (('methods', '-'), ('class_methods', '+')):
            om, nm = o.get(kind, {}), n.get(kind, {})
            for sel in sorted(set(om) | set(nm)):
                if sel not in nm:
                    removed.append((symbol, sel, om[sel]))
                elif sel not in om:
                    added.append((symbol, sel, nm[sel]))
                elif om[sel] != nm[sel]:
                    changed.append((symbol, sel, om[sel], nm[sel]))

        if o.get('super') != n.get('super'):
            out['neighbourhood'][cls + ' (superclass)'] = '%s -> %s' % (o.get('super'), n.get('super'))

        for symbol, sel, enc in removed:
            if sel in selectors:
                out['selector_changes'].append({'class': cls, 'selector': symbol + sel, 'what': 'removed', 'was': enc})
        for symbol, sel, was, now in changed:
            if sel in selectors:
                out['selector_changes'].append({'class': cls, 'selector': symbol + sel, 'what': 'encoding changed',
                                                'was': was, 'now': now})
        if added or removed or changed:
            out['neighbourhood'][cls] = {'added': added, 'removed': removed, 'changed': changed}
    return out


def render(result, classes, selectors, old_path, new_path):
    lines = ['objc-diff: %s  ->  %s' % (old_path, new_path), '']
    sc = result['selector_changes']
    lines.append('1. SELECTORS OUR SOURCES NAME THAT CHANGED (%d)' % len(sc))
    for c in sc:
        if c['what'] == 'removed':
            lines.append('   REMOVED  %s %s   (was %s)   named in %s' % (c['class'], c['selector'], c['was'], selectors.get(c['selector'][1:], '?')))
        else:
            lines.append('   CHANGED  %s %s   %s -> %s   named in %s' % (c['class'], c['selector'], c['was'], c['now'], selectors.get(c['selector'][1:], '?')))
    lines.append('')
    lines.append('2. CLASSES WE NAME THAT ARE GONE (%d)' % len(result['classes_gone']))
    for c in result['classes_gone']:
        lines.append('   GONE     %s   named in %s' % (c, classes.get(c, '?')))
    lines.append('')
    lines.append('3. CLASSES WE NAME THAT ONLY THE NEW BUILD HAS (%d)' % len(result['classes_new']))
    for c in result['classes_new']:
        lines.append('   NEW      %s   named in %s' % (c, classes.get(c, '?')))
    lines.append('')
    lines.append('4. THE NEIGHBOURHOOD OF EACH CLASS WE NAME (%d changed)' % len(result['neighbourhood']))
    for cls, body in sorted(result['neighbourhood'].items()):
        if isinstance(body, str):
            lines.append('   %s: %s' % (cls, body))
            continue
        lines.append('   %s: +%d -%d ~%d' % (cls, len(body['added']), len(body['removed']), len(body['changed'])))
        for symbol, sel, enc in body['added'][:12]:
            lines.append('       + %s%s  %s' % (symbol, sel, enc))
        for symbol, sel, enc in body['removed'][:12]:
            lines.append('       - %s%s  %s' % (symbol, sel, enc))
        for symbol, sel, was, now in body['changed'][:12]:
            lines.append('       ~ %s%s  %s -> %s' % (symbol, sel, was, now))
    return '\n'.join(lines)



# ── the one-build check ──────────────────────────────────────────────────────────────────────

def hook_blocks(root):
    """[(class, [(selector, '-'|'+', is_new, file)])] for every %hook / %subclass block."""
    blocks = []
    for path in source_files(root):
        if not path.endswith(('.x', '.xm')):
            continue
        rel = os.path.relpath(path, root)
        current, methods, is_new = None, [], False
        for line in open(path, encoding='utf-8', errors='replace'):
            m = re.match(r'\s*%hook\s+(\w+)', line)
            if m:
                current, methods, is_new = m.group(1), [], False
                continue
            if current and re.match(r'\s*%end\b', line):
                blocks.append((current, methods))
                current = None
                continue
            if not current:
                continue
            if re.match(r'\s*%new\b', line):
                is_new = True
                continue
            sel = logos_selector(line)
            if sel:
                methods.append((sel, line.lstrip()[0], is_new, rel))
                is_new = False
    return blocks


# What NSObject itself answers. A hook on one of these is a hook on the root and always legitimate.
NSOBJECT = {'init', 'dealloc', 'description', 'debugDescription', 'hash', 'isEqual:', 'class', 'copy',
            'mutableCopy', 'respondsToSelector:', 'forwardingTargetForSelector:', 'methodSignatureForSelector:',
            'forwardInvocation:', 'doesNotRecognizeSelector:', 'load', 'initialize', 'new', 'alloc', 'superclass',
            'self', 'isKindOfClass:', 'isMemberOfClass:', 'conformsToProtocol:', 'performSelector:'}


def declared_on(table, cls, kind, selector):
    """(declaring class, None) when the app's own classes declare it; (None, ancestor) when the chain
    leaves the binary at `ancestor` (UIView, UIViewController ...), where the answer cannot be read here;
    (None, None) when the chain ends at the root and nobody declared it."""
    seen = set()
    while cls and cls in table and cls not in seen:
        seen.add(cls)
        if selector in table[cls].get(kind, {}):
            return cls, None
        parent = table[cls].get('super')
        # A generated protobuf model resolves its getters on first use, so the metadata of
        # `YTIPlayerResponse` does not list `-hasAdLoggingData` although the class answers it
        # (CLAUDE.md 4.1). Not a fact this table can settle either way.
        if parent == 'GPBMessage':
            return None, 'GPBMessage (generated protobuf: getters resolve on first use)'
        if parent and parent not in table:
            return None, (None if parent == 'NSObject' else parent)
        cls = parent
    return None, None


def check_build(build, root):
    table = load(build)
    classes, _ = names_in(root)
    problems = {'missing_class': [], 'undeclared': [], 'unknowable': [], 'hooked': 0, 'classes': 0}
    seen_classes, reported = set(), set()
    for cls, methods in hook_blocks(root):
        if cls not in seen_classes:
            seen_classes.add(cls)
            problems['classes'] += 1
        if cls not in table:
            problems['missing_class'].append((cls, classes.get(cls, '?')))
            continue
        for sel, symbol, is_new, rel in methods:
            if is_new:
                continue
            problems['hooked'] += 1
            kind = 'methods' if symbol == '-' else 'class_methods'
            declared, ancestor = declared_on(table, cls, kind, sel)
            if declared or sel in NSOBJECT or (cls, symbol + sel) in reported:
                continue
            reported.add((cls, symbol + sel))
            if ancestor:
                problems['unknowable'].append((cls, symbol + sel, rel, ancestor))
            else:
                problems['undeclared'].append((cls, symbol + sel, rel))
    return problems


def render_check(problems, build):
    lines = ['objc-diff --check: %s' % build,
             '%d hooked classes, %d hooked selectors examined' % (problems['classes'], problems['hooked']), '']
    lines.append('1. %%hook ON A SELECTOR NOTHING IN THE CHAIN DECLARES (%d) -- Logos would ADD these' % len(problems['undeclared']))
    for cls, sel, rel in problems['undeclared']:
        lines.append('   %s %s   in %s' % (cls, sel, rel))
    lines.append('')
    lines.append('2. %%hook ON A CLASS THIS BUILD DOES NOT HAVE (%d) -- Logos leaves these unbound' % len(problems['missing_class']))
    for cls, rel in sorted(set(problems['missing_class'])):
        lines.append('   %s   in %s' % (cls, rel))
    lines.append('')
    lines.append('3. NOT DECLARED BY THE APP\'S OWN CLASSES, CHAIN LEAVES THE BINARY (%d) -- usually a system method, cannot be read here' % len(problems['unknowable']))
    for cls, sel, rel, ancestor in problems['unknowable']:
        lines.append('   %s %s   in %s   (inherits from %s)' % (cls, sel, rel, ancestor))
    return '\n'.join(lines)

# ── self-test: two tiny dylibs, one method removed, one re-typed, one added, one class gone ───

def selftest():
    import tempfile
    work = tempfile.mkdtemp()
    v1 = r'''
#import <Foundation/Foundation.h>
@interface MLDemoLoader : NSObject
- (void)setVideoFormatConstraint:(id)c;
- (NSArray *)filterFormats:(NSArray *)f;
- (void)onlyInOld;
- (void)retyped:(int)x;
+ (id)shared;
@end
@implementation MLDemoLoader
- (void)setVideoFormatConstraint:(id)c {}
- (NSArray *)filterFormats:(NSArray *)f { return f; }
- (void)onlyInOld {}
- (void)retyped:(int)x {}
+ (id)shared { return nil; }
@end
@interface MLGoneSoon : NSObject @end
@implementation MLGoneSoon @end
'''
    v2 = r'''
#import <Foundation/Foundation.h>
@interface MLDemoLoader : NSObject
- (void)setVideoFormatConstraint:(id)c;
- (NSArray *)filterFormats:(NSArray *)f;
- (void)retyped:(double)x;
- (void)brandNew;
+ (id)shared;
@end
@implementation MLDemoLoader
- (void)setVideoFormatConstraint:(id)c {}
- (NSArray *)filterFormats:(NSArray *)f { return f; }
- (void)retyped:(double)x {}
- (void)brandNew {}
+ (id)shared { return nil; }
@end
@interface MLArrived : NSObject @end
@implementation MLArrived @end
'''
    tweak = os.path.join(work, 'tweak', 'src')
    os.makedirs(tweak)
    open(os.path.join(tweak, 'T.x'), 'w').write('''
%hook MLDemoLoader
- (void)onlyInOld { %orig; }
- (void)retyped:(int)x { %orig; }
- (NSArray *)filterFormats:(NSArray *)f { return %orig; }
%end
static void f(void) { (void)objc_getClass("MLGoneSoon"); (void)NSClassFromString(@"MLArrived"); }
''')
    paths = []
    for name, src in (('v1', v1), ('v2', v2)):
        m = os.path.join(work, name + '.m')
        open(m, 'w').write(src)
        out = os.path.join(work, name + '.dylib')
        subprocess.run(['xcrun', '-sdk', 'iphoneos', 'clang', '-arch', 'arm64', '-miphoneos-version-min=16.0',
                        '-dynamiclib', '-fobjc-arc', '-framework', 'Foundation', m, '-o', out], check=True)
        paths.append(out)

    old, new = load(paths[0]), load(paths[1])
    classes, selectors = names_in(os.path.join(work, 'tweak'))
    result = diff(old, new, classes, selectors)

    failures = []

    def check(condition, text):
        print(('ok    ' if condition else 'FAIL  ') + text)
        if not condition:
            failures.append(text)

    changes = {(c['selector'], c['what']) for c in result['selector_changes']}
    check(('-onlyInOld', 'removed') in changes, 'a named selector that was removed is reported')
    check(('-retyped:', 'encoding changed') in changes, 'a named selector whose encoding changed is reported')
    check(not any(c['selector'] == '-filterFormats:' for c in result['selector_changes']), 'an unchanged named selector is not')
    check(result['classes_gone'] == ['MLGoneSoon'], 'a named class that disappeared is reported')
    check(result['classes_new'] == ['MLArrived'], 'a named class that only the new build has is reported')
    added = [a[1] for a in result['neighbourhood']['MLDemoLoader']['added']]
    check(added == ['brandNew'], 'the neighbourhood lists what was added')
    problems = check_build(paths[1], os.path.join(work, 'tweak'))
    undeclared = {(c, s) for c, s, _ in problems['undeclared']}
    check_ok = ('MLDemoLoader', '-onlyInOld') in undeclared and ('MLDemoLoader', '-retyped:') not in undeclared
    check(check_ok, '--check: a hooked selector the new build does not declare is reported, a declared one is not')
    check(('MLDemoLoader', '-filterFormats:') not in undeclared, '--check: an unchanged hooked selector is not reported')
    text = render(result, classes, selectors, 'old', 'new')
    check('REMOVED  MLDemoLoader -onlyInOld' in text and 'GONE     MLGoneSoon' in text, 'the report prints them')
    print('\nall passed' if not failures else '\n%d FAILED' % len(failures))
    return 1 if failures else 0


if __name__ == '__main__':
    if '--selftest' in sys.argv:
        sys.exit(selftest())

    args = [a for a in sys.argv[1:]]
    tweak = pattern = None
    if '--check' in args:
        i = args.index('--check'); build = args[i + 1]; del args[i:i + 2]
        if '--tweak' not in args:
            sys.exit(__doc__)
        j = args.index('--tweak')
        print(render_check(check_build(build, args[j + 1]), build))
        sys.exit(0)
    if '--tweak' in args:
        i = args.index('--tweak'); tweak = args[i + 1]; del args[i:i + 2]
    if '--class' in args:
        i = args.index('--class'); pattern = args[i + 1]; del args[i:i + 2]
    if len(args) != 2 or not (tweak or pattern):
        sys.exit(__doc__)

    old, new = load(args[0]), load(args[1])
    if tweak:
        classes, selectors = names_in(tweak)
    else:
        classes, selectors = {}, {}
    if pattern:
        rx = re.compile(pattern)
        for name in set(old) | set(new):
            if rx.search(name):
                classes.setdefault(name, '--class')
        for name in classes:
            for table in (old.get(name, {}), new.get(name, {})):
                for kind in ('methods', 'class_methods'):
                    for sel in table.get(kind, {}):
                        selectors.setdefault(sel, '--class')
    print(render(diff(old, new, classes, selectors), classes, selectors, args[0], args[1]))
