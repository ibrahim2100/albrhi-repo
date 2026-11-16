#!/usr/bin/env python3
"""Give every Albrhi package its own icon and its Sileo section in the APT index.   tidy-index.py <output-dir> <base-url> <catalog.json>

Until 2026-11-16 every package in the source showed one generic orange download arrow and sat in one section called "Tweaks", so the source read as one tool
repeated. brand/catalog.json says which icon and section each package id gets. This runs on `Packages` after dpkg-scanpackages (the .debs are not touched, so
nothing is rebuilt, and old versions follow). A package gets an icon only when the file exists in <output-dir>/icons; a package not in the catalogue (a
foreign one in extra-debs) is left exactly as it was.
"""
import json, os, sys

out, base, catalog = sys.argv[1], sys.argv[2].rstrip('/'), sys.argv[3]
rules = {}
for entry in json.load(open(catalog, encoding='utf-8'))['packages']:
    for pid in entry['ids']: rules[pid] = entry
path = os.path.join(out, 'Packages')
stanzas = open(path, encoding='utf-8').read().rstrip('\n').split('\n\n')
touched, no_icon = [], set()
for i, st in enumerate(stanzas):
    lines = st.split('\n')
    pid = next((l.split(':', 1)[1].strip() for l in lines if l.startswith('Package:')), None)
    rule = rules.get(pid)
    if not rule: continue
    have = os.path.isfile(os.path.join(out, 'icons', rule['icon'] + '.png'))
    if not have: no_icon.add(rule['icon'])
    lines = [l for l in lines if not (l.startswith('Section:') or (have and l.startswith('Icon:')))]
    lines.append('Section: ' + rule['section'])
    if have: lines.append('Icon: %s/icons/%s.png' % (base, rule['icon']))
    stanzas[i] = '\n'.join(lines); touched.append(pid)
open(path, 'w', encoding='utf-8').write('\n\n'.join(stanzas) + '\n\n')
print('tidy-index: icon and section set for %d package entries' % len(touched))
for ic in sorted(no_icon): print('tidy-index: NO FILE icons/%s.png, icon left as it was' % ic)
