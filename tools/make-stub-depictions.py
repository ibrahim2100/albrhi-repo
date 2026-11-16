#!/usr/bin/env python3
"""Small depictions (JSON for Sileo, HTML for the rest) for the individual packages that never had one.

    make-stub-depictions.py <output-dir> <base-url>

`com.albrhi.tiktok` and `com.albrhi.twitter` point at depictions/albrhi-tiktok.html and albrhi-twitter.html, which were never generated (404 since the day
the packages were split out of the suite), so a person opening either in a package manager saw an error page. Each gets the same header card as its docs
page, what the package is, who it belongs to and where the full page is. Written only when the file is absent: a real depiction is never replaced.
Text is read from the tweak's own `control` so it cannot drift from the package.
"""
import json, os, re, sys

out, base = sys.argv[1], sys.argv[2].rstrip('/')
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = 'https://github.com/ibrahim2100/albrhi-repo/blob/main/docs/tweaks/'
STUBS = [  # slug, tweak dir, card (cards/<card>.jpg), docs page, accent, name
    ('albrhi-tiktok',  'tiktok',  'tiktok',  'tiktok.md', '#25F4EE', 'Albrhi for TikTok'),
    ('albrhi-twitter', 'twitter', 'twitter', 'x.md',      '#8FA3BA', 'Albrhi for X'),
]
LEAD = 'This package is the single-app build. The same tweak is inside **Albrhi** (`com.albrhi`): one install, one update, and every other app tweak. Install that one unless you only want this app.'

def description(tweak):
    text = open(os.path.join(root, 'tweaks', tweak, 'control'), encoding='utf-8').read()
    m = re.search(r'^Description:\s*(.*?)(?=^\S)', text + '\nX', re.S | re.M)
    return re.sub(r'\s+', ' ', m.group(1)).strip()

os.makedirs(os.path.join(out, 'depictions'), exist_ok=True)
for slug, tweak, card, page, accent, name in STUBS:
    jpath = os.path.join(out, 'depictions', slug + '.json')
    if os.path.exists(jpath):
        print('kept', slug); continue
    desc = description(tweak)
    ar = {'tiktok': 'زر تحميل في الفيد وخصوصية أكثر', 'twitter': 'حمّل الوسائط وتحكّم بمفاتيح X'}[tweak]
    view = lambda **k: k
    dep = {'minVersion': '0.1', 'class': 'DepictionTabView', 'tintColor': accent, 'headerImage': '%s/cards/%s.jpg' % (base, card),
           'tabs': [{'class': 'DepictionStackView', 'tabname': 'Details', 'views': [
               view(**{'class': 'DepictionMarkdownView', 'markdown': desc, 'useSpacing': True}),
               view(**{'class': 'DepictionMarkdownView', 'markdown': ar, 'useSpacing': True}),
               view(**{'class': 'DepictionSeparatorView'}),
               view(**{'class': 'DepictionMarkdownView', 'markdown': LEAD, 'useSpacing': True}),
               view(**{'class': 'DepictionTableButtonView', 'title': 'The full page', 'action': DOCS + page, 'openExternal': 'true'}),
               view(**{'class': 'DepictionTableButtonView', 'title': 'Report an issue', 'action': 'https://github.com/ibrahim2100/albrhi-repo/issues', 'openExternal': 'true'}),
           ]}]}
    json.dump(dep, open(jpath, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
    html = ('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>%s</title>'
            '<style>:root{--a:%s}body{margin:0;padding:24px 18px 60px;font:16px/1.55 -apple-system,system-ui,sans-serif;background:#fff;color:#1c1c1e}'
            '@media(prefers-color-scheme:dark){body{background:#000;color:#f5f5f7}}main{max-width:620px;margin:0 auto}'
            'img{display:block;width:100%%;border-radius:14px;margin:0 0 20px}h1{font-size:26px;margin:0 0 10px}a{color:var(--a)}</style></head><body><main>'
            '<img src="%s/cards/%s.jpg" alt=""><h1>%s</h1><p>%s</p><p dir="rtl">%s</p><p>%s</p>'
            '<p><a href="%s%s">The full page</a> · <a href="https://github.com/ibrahim2100/albrhi-repo/issues">Report an issue</a></p></main></body></html>'
            ) % (name, accent, base, card, name, desc, ar, LEAD.replace('**', '').replace('`', ''), DOCS, page)
    open(os.path.join(out, 'depictions', slug + '.html'), 'w', encoding='utf-8').write(html)
    print('wrote', slug)
