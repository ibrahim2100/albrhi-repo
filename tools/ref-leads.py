#!/usr/bin/env python3
"""Leads out of a reference tweak: the selectors it names that belong to *the app*, not to Apple.

    python3 tools/ref-leads.py <reference.dylib> [--tweak tweaks/instagram] [--grep seen,story]

**What it is for.** A closed reference tweak (RyukGram, Rocket, a paid one) hooks the app's own
classes, and the selectors it needs are sitting in its `__objc_methname` section as plain text even
when everything else is obfuscated -- Rocket 4.23.1 hashes its class names and encrypts its strings,
and still names `storySeenStateStore`, `hasSeenMediaId:forReelPK:` and
`profileAvatarActionsController:showExpandedProfilePicFrom:isLongPress:` in the clear, because the
runtime has to be asked for them by name. Subtracting what Apple's SDK headers declare and what the
reference defines itself leaves the app's internals the reference *depends on*.

**What it is not.** A selector in that list says the reference names it, not that the app has it, not
what it does, and not which build. Every lead is unverified until `tools/objc-diff.py --check` or
`objc-classes.py --find-method` has asked the app's own binary. It also reads nothing about licence,
store or entitlement code: those selectors are bucketed apart and labelled, because CLAUDE.md §2
reads a paid reference's architecture and leaves its protection alone.

With `--tweak`, selectors our own sources already name are split off, so what is left is what this
project does not touch yet.
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SDK = os.path.expanduser(os.environ.get('SCI_SDK', '~/theos/sdks/iPhoneOS16.2.sdk'))
LIBRARIES = re.compile(r'^(sd_|SD|sdweb|yy|ma_|MB|SAM|nyt|NYT|_sd|xdc)|SDImage|SDWeb|animatedImage|webp|apng', re.I)
PROTECTION = re.compile(r'subscription|licen|purchase|storekit|entitle|paywall|receipt|trial|jailbreak|integrity|attest', re.I)


def methnames(path):
    raw = subprocess.run(['otool', '-s', '__TEXT', '__objc_methname', path], capture_output=True).stdout
    data = bytearray()
    for line in raw.decode().splitlines()[2:]:
        parts = line.split()
        for word in parts[1:]:
            data += bytes.fromhex(word)[::-1]
    return {s.decode('ascii', 'ignore') for s in data.split(b'\0') if s}


def sdk_vocabulary():
    vocab = set()
    ident = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
    frameworks = os.path.join(SDK, 'System/Library/Frameworks')
    if not os.path.isdir(frameworks):
        sys.exit('no SDK at %s (set SCI_SDK) -- the headers are what separate Apple\'s selectors from the app\'s' % SDK)
    for root, _, files in os.walk(frameworks):
        if '/Headers' not in root:
            continue
        for name in files:
            if name.endswith('.h'):
                vocab.update(ident.findall(open(os.path.join(root, name), errors='ignore').read()))
    objc = os.path.join(SDK, 'usr/include/objc')
    for name in os.listdir(objc) if os.path.isdir(objc) else []:
        vocab.update(ident.findall(open(os.path.join(objc, name), errors='ignore').read()))
    return vocab


def own_selectors(path):
    dump = '/tmp/albrhi-ref-leads-%d.json' % os.getpid()
    subprocess.run([sys.executable, os.path.join(HERE, 'objc-classes.py'), path, '--dump', dump],
                   check=True, stdout=subprocess.DEVNULL)
    classes = json.load(open(dump))['classes']
    os.unlink(dump)
    own = set()
    for body in classes.values():
        own.update(body['methods'])
        own.update(body['class_methods'])
        for prop in body['properties']:
            name = prop.split(' : ')[0]
            own.add(name)
            own.add('set' + name[:1].upper() + name[1:] + ':')
    return own, classes


def sources_text(root):
    chunks = []
    for base, _, files in os.walk(root):
        for name in files:
            if name.endswith(('.m', '.mm', '.x', '.xm', '.h')):
                chunks.append(open(os.path.join(base, name), errors='ignore').read())
    return '\n'.join(chunks)


def main():
    args = sys.argv[1:]
    tweak = grep = None
    if '--tweak' in args:
        i = args.index('--tweak'); tweak = args[i + 1]; del args[i:i + 2]
    if '--grep' in args:
        i = args.index('--grep'); grep = args[i + 1].split(','); del args[i:i + 2]
    if len(args) != 1:
        sys.exit(__doc__)
    path = args[0]

    vocab = sdk_vocabulary()
    own, classes = own_selectors(path)
    obfuscated = sum(1 for n in classes if re.match(r'z[0-9a-f]{20,}', n))

    leads, protection = [], []
    for sel in sorted(methnames(path)):
        if sel in own or re.match(r'^_?z[0-9a-f]{8}|^\.cxx|^T@|^T[a-zA-Z]+,', sel):
            continue
        if LIBRARIES.search(sel) or len(sel) < 7:
            continue
        parts = [p for p in sel.split(':') if p]
        if parts and any(p not in vocab and p.lstrip('_') not in vocab for p in parts):
            (protection if PROTECTION.search(sel) else leads).append(sel)

    ours = []
    if tweak:
        text = sources_text(tweak)
        ours = [s for s in leads if s.split(':')[0] in text]
        leads = [s for s in leads if s not in set(ours)]
    if grep:
        leads = [s for s in leads if any(g.lower() in s.lower() for g in grep)]
        ours = [s for s in ours if any(g.lower() in s.lower() for g in grep)]

    print('%s: %d classes (%d with hashed names), %d own selectors' % (os.path.basename(path), len(classes), obfuscated, len(own)))
    print('%d app-side selectors named%s' % (len(leads) + len(ours), ', %d already named in %s' % (len(ours), tweak) if tweak else ''))
    print()
    print('LEADS (unverified until asked of the app\'s own binary):')
    for sel in leads:
        print('  ' + sel)
    if ours:
        print('\nALREADY IN OUR SOURCES (%d):' % len(ours))
        for sel in ours:
            print('  ' + sel)
    if protection:
        print('\nNOT EXAMINED -- licence / store / protection (%d names, listed only so they are not mistaken for features):' % len(protection))
        for sel in protection:
            print('  ' + sel)


if __name__ == '__main__':
    main()
