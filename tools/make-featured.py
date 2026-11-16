#!/usr/bin/env python3
"""Sileo's featured banners: the carousel at the top of the source's page.   make-featured.py <output-dir> <base-url>

Writes <output-dir>/sileo-featured.json (the file name and the root-level place are Sileo's). Format, from developer.getsileo.app/sileo-featured:
root `class: FeaturedBannersView`, `itemSize`, `itemCornerRadius`, and `banners`, each `url` (the IMAGE), `title`, `package`, `hideShadow`.
Sileo draws the title over the image itself, so the pictures (brand/out/featured, made by brand/build.py) carry no text.

A banner is written only when its picture is in <output-dir>/featured and its package is in <output-dir>/Packages (so a package that is withheld or
gone never leaves a banner that opens nothing). `package` is the **roothide** identity: the owner's phone is roothide and one banner can name one id;
on a rootless phone whether Sileo finds a package of the other flavour is not known (not seen on a device).
"""
import json, os, sys

out, base = sys.argv[1], sys.argv[2].rstrip('/')
BANNERS = [  # picture, title, package
    ('albrhi', 'Albrhi', 'com.albrhi.roothide'),
    ('whatsapp', 'WhatsApp', 'com.albrhi.whatsapp.roothide'),
    ('instagram', 'Instagram', 'com.albrhi.tweak.roothide'),
    ('youtube', 'YouTube', 'com.albrhi.youtube.roothide'),
    ('tiktok', 'TikTok', 'com.albrhi.tiktok.roothide'),
    ('twitter', 'X', 'com.albrhi.twitter.roothide'),
    ('nextup', 'NextUp', 'com.albrhi.nextup.roothide'),
    ('watch', 'Watch', 'com.albrhi.watch.roothide'),
]
packages = set()
pk = os.path.join(out, 'Packages')
if os.path.isfile(pk):
    for line in open(pk, encoding='utf-8'):
        if line.startswith('Package: '): packages.add(line[9:].strip())
banners, skipped = [], []
for pic, title, pkg in BANNERS:
    if not os.path.isfile(os.path.join(out, 'featured', pic + '.jpg')) or (packages and pkg not in packages):
        skipped.append(title); continue
    banners.append({'url': '%s/featured/%s.jpg' % (base, pic), 'title': title, 'package': pkg, 'hideShadow': False})
doc = {'class': 'FeaturedBannersView', 'itemSize': '{263, 148}', 'itemCornerRadius': 10, 'banners': banners}
json.dump(doc, open(os.path.join(out, 'sileo-featured.json'), 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
print('sileo-featured.json: %d banners%s' % (len(banners), (' (left out: ' + ', '.join(skipped) + ')') if skipped else ''))
