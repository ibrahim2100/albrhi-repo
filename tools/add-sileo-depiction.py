#!/usr/bin/env python3
"""Put `SileoDepiction:` into the APT index for the packages that opt in.

    add-sileo-depiction.py <output-dir> <base-url> <package> [<package> ...]

Why this exists: `dpkg-scanpackages` writes `Depiction:` but drops `SileoDepiction:` from every stanza (checked 2026-11-16: the field is in the
.debs and in no line of Packages), so Sileo has only ever been shown the HTML page and never a package's native JSON depiction. Turning it on for
every package at once was **not** done: the old individual tiktok and twitter packages still in the index point at depictions that are 404, and a
foreign package in the source points at a file that is not JSON; Sileo would show an error where it now shows a page. So it is an opt-in list, and
a package gets the field only when the file it names exists in <output-dir> (nothing is asked of the network).
"""
import os, subprocess, sys

out, base = sys.argv[1], sys.argv[2].rstrip('/')
wanted = set(sys.argv[3:])
path = os.path.join(out, 'Packages')
stanzas = open(path, encoding='utf-8').read().rstrip('\n').split('\n\n')
done, skipped = [], []
for i, st in enumerate(stanzas):
    lines = st.split('\n')
    fields = {l.split(':', 1)[0]: l.split(':', 1)[1].strip() for l in lines if ':' in l and not l.startswith(' ')}
    if fields.get('Package') not in wanted or 'SileoDepiction' in fields:
        continue
    deb = os.path.join(out, fields['Filename'])
    url = subprocess.run(['dpkg-deb', '-f', deb, 'SileoDepiction'], capture_output=True, text=True).stdout.strip()
    if not url.startswith(base + '/') or not os.path.isfile(os.path.join(out, url[len(base) + 1:])):
        skipped.append((fields['Package'], url or 'no SileoDepiction in the control file'))
        continue
    at = max((n for n, l in enumerate(lines) if l.startswith('Depiction:')), default=len(lines) - 1)
    lines.insert(at + 1, 'SileoDepiction: ' + url)
    stanzas[i] = '\n'.join(lines)
    done.append(fields['Package'])
open(path, 'w', encoding='utf-8').write('\n\n'.join(stanzas) + '\n\n')
print('SileoDepiction added for:', ', '.join(done) or 'nobody')
for name, why in skipped: print('SileoDepiction NOT added for %s (%s)' % (name, why))
