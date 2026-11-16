#!/usr/bin/env python3
"""The Albrhi icon family: one template, one stroke, one signature dot, a hue and a glyph per product.   python3 brand/build.py

Every icon is the same rounded square with the same top light and the same round-capped white stroke as the master mark (the A with its dot).
The dot is the family's signature: in the A it is the point under the roof, in the others it is the sun, the knob, the eyes, the hub.
Nothing here imitates another company's logo: the glyphs are generic (a picture, a play triangle, a speech bubble, a video frame, a ghost, skip-next, a watch).
Writes brand/icons/<slug>.svg and .png (1024), brand/icons/512/<slug>.png, brand/out/family.png (the sheet) and brand/out/source.png (the source's own icon).
"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ICONS = os.path.join(HERE, 'icons'); OUT = os.path.join(HERE, 'out'); TMP = os.path.join(HERE, '.build')
for d in (ICONS, os.path.join(ICONS, '512'), OUT, TMP): os.makedirs(d, exist_ok=True)
CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

W = 'stroke="#fff" fill="none" stroke-linecap="round" stroke-linejoin="round"'
GLYPH = {
 # the master mark: a roof and the point under it
 'albrhi': '<path d="M133 387 L256 125 L379 387" %s stroke-width="61"/><circle cx="256" cy="297" r="31" fill="#fff"/>' % W,
 # a picture: frame, hill, and the sun is the dot
 'instagram': '<rect x="118" y="132" width="276" height="248" rx="48" %s stroke-width="40"/><path d="M180 324 L234 268 L284 314 L326 274" %s stroke-width="36"/><circle cx="326" cy="204" r="29" fill="#fff"/>' % (W, W),
 # play, and the progress knob is the dot
 'youtube': '<path d="M204 140 L204 322 L356 231 Z" fill="#fff" stroke="#fff" stroke-width="30" stroke-linejoin="round"/><path d="M128 392 H384" stroke="#fff" stroke-opacity=".38" stroke-width="34" stroke-linecap="round"/><path d="M128 392 H262" stroke="#fff" stroke-width="34" stroke-linecap="round"/><circle cx="262" cy="392" r="31" fill="#fff"/>',
 # a speech bubble with the dot inside
 'twitter': '<path d="M168 128 H344 A64 64 0 0 1 408 192 V282 A64 64 0 0 1 344 346 H252 L176 410 V346 A64 64 0 0 1 104 282 V192 A64 64 0 0 1 168 128 Z" %s stroke-width="40"/><circle cx="256" cy="237" r="31" fill="#fff"/>' % W,
 # a portrait video frame, the dot is the indicator under it
 'tiktok': '<rect x="164" y="100" width="184" height="296" rx="46" stroke="url(#tt)" fill="none" stroke-width="40"/><path d="M232 206 L232 296 L298 251 Z" fill="#fff" stroke="#fff" stroke-width="22" stroke-linejoin="round"/><circle cx="256" cy="438" r="22" fill="#fff"/>',
 # a ghost: the eyes are the dots
 'whatsapp': '<path d="M130 398 V238 C130 164 184 114 256 114 C328 114 382 164 382 238 V398 L338 360 L297 398 L256 360 L215 398 L174 360 Z" %s stroke-width="40"/><circle cx="212" cy="248" r="24" fill="#fff"/><circle cx="300" cy="248" r="24" fill="#fff"/>' % W,
 # skip to the next, the dot waits under it
 'nextup': '<path d="M152 140 L152 332 L304 236 Z" fill="#fff" stroke="#fff" stroke-width="30" stroke-linejoin="round"/><path d="M360 140 V332" %s stroke-width="44"/><circle cx="256" cy="422" r="26" fill="#fff"/>' % W,
 # a watch: the hub is the dot
 'ytmusic': '<circle cx="204" cy="352" r="56" fill="#fff"/><path d="M260 352 V156 L376 196 V258" %s stroke-width="40"/><circle cx="376" cy="258" r="0" fill="#fff"/>' % W,
 'panel': '<path d="M122 170 H390" stroke="#fff" stroke-opacity=".42" stroke-width="30" stroke-linecap="round"/><path d="M122 256 H390" stroke="#fff" stroke-opacity=".42" stroke-width="30" stroke-linecap="round"/><path d="M122 342 H390" stroke="#fff" stroke-opacity=".42" stroke-width="30" stroke-linecap="round"/><circle cx="196" cy="170" r="38" fill="#fff"/><circle cx="326" cy="256" r="38" fill="#fff"/><circle cx="238" cy="342" r="38" fill="#fff"/>',
 'spotify': '<path d="M132 300 V212 M194 340 V172 M256 380 V132 M318 330 V182 M380 290 V222" %s stroke-width="40"/><circle cx="256" cy="440" r="0" fill="#fff"/>' % W,
 'watch': '<circle cx="256" cy="256" r="122" %s stroke-width="40"/><path d="M256 256 V190" %s stroke-width="30"/><path d="M256 256 L304 284" %s stroke-width="30"/><circle cx="256" cy="256" r="22" fill="#fff"/><path d="M214 116 L224 72 H288 L298 116" %s stroke-width="30"/><path d="M214 396 L224 440 H288 L298 396" %s stroke-width="30"/>' % (W, W, W, W, W),
}
# (slug, name, top colour, bottom colour, optional middle)
FAMILY = [
 ('albrhi',    'Albrhi',            '#3BE88C', '#0B6E3D', None),
 ('instagram', 'for Instagram',     '#FFC25A', '#8B3FD9', '#F0447A'),
 ('youtube',   'for YouTube',       '#FF6E60', '#A80F18', None),
 ('twitter',   'for Twitter',             '#566577', '#0A0E13', None),
 ('tiktok',    'for TikTok',        '#2B2B47', '#04040A', None),
 ('whatsapp',  'for WhatsApp',      '#34E7B2', '#067A66', None),
 ('nextup',    'NextUp',            '#9686FF', '#3524B5', None),
 ('watch',     'Watch',             '#5CC8FF', '#1259B8', None),
]
# icons the README draws but the source does not list: YouTube Music and Panel ship inside Albrhi, Spotify is not published
EXTRA = [
 ('ytmusic',   'YouTube Music',     '#FF7BB0', '#A8104A', None),
 ('panel',     'Panel',             '#93A1B8', '#364159', None),
 ('spotify',   'Spotify',           '#C2F56F', '#2F7A12', None),
]

def svg(slug, top, bot, mid):
    stops = '<stop offset="0" stop-color="%s"/>' % top
    if mid: stops += '<stop offset=".52" stop-color="%s"/>' % mid
    stops += '<stop offset="1" stop-color="%s"/>' % bot
    extra = '<linearGradient id="tt" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#25F4EE"/><stop offset="1" stop-color="#FE2C55"/></linearGradient>' if slug == 'tiktok' else ''
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 512 512"><defs>'
            '<linearGradient id="g" x1="0.2" y1="0" x2="0.8" y2="1">%s</linearGradient>'
            '<linearGradient id="h" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".22"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>%s'
            '<clipPath id="c"><rect width="512" height="512" rx="120"/></clipPath></defs>'
            '<g clip-path="url(#c)"><rect width="512" height="512" fill="url(#g)"/><rect width="512" height="318" fill="url(#h)"/></g>%s</svg>') % (stops, extra, GLYPH[slug])

def render(html, out, w, h, transparent=False):
    path = os.path.join(TMP, os.path.basename(out) + '.html'); open(path, 'w', encoding='utf-8').write(html)
    cmd = [CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', '--window-size=%d,%d' % (w, h), '--virtual-time-budget=2500']
    if transparent: cmd.append('--default-background-color=00000000')
    subprocess.run(cmd + ['--screenshot=' + out, 'file://' + path], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

for slug, name, top, bot, mid in FAMILY + EXTRA:
    s = svg(slug, top, bot, mid)
    open(os.path.join(ICONS, slug + '.svg'), 'w').write(s)
    render('<style>html,body{margin:0;background:transparent}</style>' + s, os.path.join(ICONS, slug + '.png'), 1024, 1024, True)
    subprocess.run(['sips', '--resampleWidth', '512', os.path.join(ICONS, slug + '.png'), '--out', os.path.join(ICONS, '512', slug + '.png')], check=True, stdout=subprocess.DEVNULL)
    print('icon', slug)

# the sheet: the family on dark and light, and the package list as Sileo draws it
def tile(slug, size): return '<img src="../icons/%s.png" style="width:%dpx;height:%dpx;display:block">' % (slug, size, size)
CSS = '*{box-sizing:border-box;margin:0}body{font-family:-apple-system,"SF Pro Display",Helvetica,sans-serif;-webkit-font-smoothing:antialiased}'
grid = ''.join('<div style="text-align:center">%s<div style="margin-top:14px;font-size:22px;font-weight:600">%s</div></div>' % (tile(s, 140), ('Albrhi ' + n) if s != 'albrhi' else 'Albrhi') for s, n, *_ in FAMILY)
def rows(dark):
    bg, fg, sub, line = ('#000', '#fff', '#8e8e93', '#2c2c2e') if dark else ('#fff', '#000', '#6e6e73', '#e5e5ea')
    r = ''
    desc = {'albrhi': 'The social apps, in one install', 'instagram': 'Downloads, privacy, ads', 'youtube': 'Download Centre, SponsorBlock', 'twitter': 'Downloads and feature switches',
            'tiktok': 'Downloads, comments, clean-up', 'whatsapp': 'Privacy, in your hands', 'nextup': 'What plays next', 'watch': 'Pair a newer watchOS'}
    for s, n, *_ in FAMILY:
        r += '<div style="display:flex;align-items:center;gap:16px;padding:12px 18px;border-bottom:1px solid %s">%s<div><div style="font-size:19px;font-weight:600;color:%s">%s</div><div style="font-size:15px;color:%s">%s</div></div></div>' % (line, tile(s, 56), fg, ('Albrhi ' + n) if s != 'albrhi' else 'Albrhi', sub, desc[s])
    return '<div style="background:%s;border-radius:18px;overflow:hidden;width:440px;border:1px solid %s">%s</div>' % (bg, line, r)
sheet = ('<!doctype html><meta charset="utf-8"><style>%s</style><body style="width:1700px;height:800px;background:linear-gradient(160deg,#071a11,#020a06);color:#fff;padding:56px 64px;position:relative">'
         '<div style="font-size:15px;letter-spacing:3px;color:#7CF2B3;font-weight:700">THE ALBRHI FAMILY</div>'
         '<div style="display:grid;grid-template-columns:repeat(3,200px);gap:26px 28px;margin-top:30px">%s</div>'
         '<div style="position:absolute;right:64px;top:56px;display:flex;gap:22px">%s%s</div></body>') % (CSS, grid, rows(True), rows(False))
render(sheet, os.path.join(OUT, 'family.png'), 1700, 800)
print('sheet')
# the source's own icon is the master mark
subprocess.run(['sips', '--resampleWidth', '512', os.path.join(ICONS, 'albrhi.png'), '--out', os.path.join(OUT, 'source.png')], check=True, stdout=subprocess.DEVNULL)

# ---------------------------------------------------------------- the repository's hero and social preview (1600 x 800, and the same at 1280 x 640)
import math
CX, CY = 1160, 420
R1, R2, SZ = 212, 335, 96
NAMES = {'albrhi': 'Albrhi', 'instagram': 'Instagram', 'youtube': 'YouTube', 'twitter': 'X', 'tiktok': 'TikTok', 'whatsapp': 'WhatsApp', 'nextup': 'NextUp', 'watch': 'Watch'}
def orbit_icon(slug, r, deg, size):
    x = CX + r * math.cos(math.radians(deg)); y = CY + r * math.sin(math.radians(deg))
    return ('<div style="position:absolute;left:%dpx;top:%dpx;width:%dpx;text-align:center;transform:translate(-50%%,-%dpx)">'
            '<img src="../icons/%s.png" style="width:%dpx;height:%dpx;display:block;margin:0 auto;border-radius:%dpx;box-shadow:0 18px 40px rgba(0,0,0,.45)">'
            '<div style="margin-top:9px;font-size:19px;font-weight:600;color:#cfeedd">%s</div></div>') % (x, y, size + 60, size // 2, slug, size, size, int(size * .235), NAMES[slug])
inner = [('instagram', -135), ('youtube', -45), ('tiktok', 45), ('twitter', 135)]
outer = [('whatsapp', -90), ('nextup', 24), ('watch', 156)]
cluster = ('<svg style="position:absolute;left:0;top:0" width="1600" height="800" viewBox="0 0 1600 800">'
           '<circle cx="%d" cy="%d" r="%d" fill="rgba(42,208,120,.08)" stroke="rgba(124,242,179,.6)" stroke-width="2.5"/>'
           '<circle cx="%d" cy="%d" r="%d" fill="none" stroke="rgba(124,242,179,.34)" stroke-width="2.5" stroke-dasharray="2 13" stroke-linecap="round"/></svg>') % (CX, CY, R1, CX, CY, R2)
for slug, deg in inner: cluster += orbit_icon(slug, R1, deg, SZ)
for slug, deg in outer: cluster += orbit_icon(slug, R2, deg, SZ)
cluster += ('<img src="../icons/albrhi.png" style="position:absolute;left:%dpx;top:%dpx;width:136px;height:136px;border-radius:32px;box-shadow:0 0 90px rgba(42,208,120,.6),0 20px 50px rgba(0,0,0,.5)">') % (CX - 68, CY - 68)
legend = ('<div style="position:absolute;right:70px;bottom:40px;font-size:18px;color:rgba(255,255,255,.62);line-height:1.8">'
          '<span style="display:inline-block;width:26px;border-top:3px solid rgba(124,242,179,.8);vertical-align:middle;margin-right:10px"></span>inside the Albrhi package<br>'
          '<span style="display:inline-block;width:26px;border-top:3px dotted rgba(124,242,179,.6);vertical-align:middle;margin-right:10px"></span>their own packages</div>')
chips = ''.join('<span style="display:inline-block;margin:0 10px 10px 0;padding:9px 18px;border-radius:99px;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.16);color:#d8f5e5;font-size:21px;font-weight:600">%s</span>' % c
                for c in ('Bilingual', 'Native', 'Free'))
left = ('<div style="position:absolute;left:92px;top:200px;width:680px">'
        '<div style="font-size:170px;font-weight:800;letter-spacing:-7px;line-height:1">Albrhi</div>'
        '<div style="font-family:\'SF Arabic\',\'Geeza Pro\',-apple-system,sans-serif;font-size:80px;font-weight:700;color:#7CF2B3;margin-top:6px">البرهي</div>'
        '<div style="font-size:32px;color:rgba(255,255,255,.78);margin-top:20px;font-weight:500">iOS tweaks, built in the open.</div>'
        '<div style="margin-top:30px">%s</div></div>') % chips
foot = '<div style="position:absolute;left:92px;bottom:44px;font-size:21px;color:rgba(255,255,255,.55);font-family:ui-monospace,Menlo,monospace">ibrahim2100.github.io/albrhi-repo</div>'
hero = ('<!doctype html><meta charset="utf-8"><style>%s</style><body style="width:1600px;height:800px;position:relative;overflow:hidden;color:#fff;'
        'background:radial-gradient(900px 600px at 78%% 50%%,rgba(42,208,120,.30),transparent 70%%),radial-gradient(700px 500px at 8%% 0%%,rgba(20,160,140,.22),transparent 70%%),linear-gradient(160deg,#071a11,#04100a 60%%,#020a06)">'
        '<div style="position:absolute;inset:0;opacity:.07;background-image:radial-gradient(#fff 1.2px,transparent 1.4px);background-size:34px 34px"></div>%s%s%s%s</body>') % (CSS, left, cluster, legend, foot)
def render_scaled(html, out, w, h, scale):
    path = os.path.join(TMP, os.path.basename(out) + '.html'); open(path, 'w', encoding='utf-8').write(html)
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=%s' % scale, '--window-size=%d,%d' % (w, h), '--virtual-time-budget=3000',
                    '--screenshot=' + out, 'file://' + path], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
render_scaled(hero, os.path.join(OUT, 'hero.png'), 1600, 800, 1)
render_scaled(hero, os.path.join(OUT, 'social-preview.png'), 1600, 800, 0.8)
print('hero, social-preview')

# ---------------------------------------------------------------- one header card per tweak page (docs/tweaks/<slug>.md), 1600 x 560
# No version numbers in the pictures: they would be stale at the next release; the page text carries them.
COLORS = {s: (t, b, m) for s, n, t, b, m in FAMILY + EXTRA}
ACC = {'instagram': '#FFC25A', 'youtube': '#FF8E84', 'twitter': '#B6C4D6', 'tiktok': '#25F4EE', 'ytmusic': '#FF9EC6', 'panel': '#B9C5DA', 'spotify': '#C2F56F', 'nextup': '#B3A8FF', 'watch': '#7CD2FF', 'albrhi': '#7CF2B3'}
TWEAK_CARDS = [
 # slug, docs page, title, arabic line, english line, four features, corner badge
 ('albrhi', 'albrhi', 'Albrhi', 'ثبّتها مرة وحدة وخذ كل الأدوات', 'One install: Instagram, YouTube, X, TikTok, YouTube Music and the panel.', ['Five apps', 'One panel', 'One update', 'Free'], 'THE FRONT DOOR'),
 ('instagram', 'instagram', 'Albrhi for Instagram', 'حمّل كل شي وتصفّح بهدوء', 'Download anything, hide the noise, browse invisibly.', ['Downloads', 'Stories, no receipt', 'Unsent messages kept', 'A quieter feed'], 'INSIDE ALBRHI'),
 ('youtube', 'youtube', 'Albrhi for YouTube', 'تحميل بلا إعلانات وتشغيل بالخلفية', 'Downloads that last, no ads, SponsorBlock, background play.', ['Download Centre tab', 'No ads', 'SponsorBlock', 'Background play'], 'INSIDE ALBRHI'),
 ('twitter', 'x', 'Albrhi for X', 'حمّل الوسائط وتحكّم بمفاتيح X', 'Save any video, photo or GIF, and switch off what X does.', ['Media downloads', 'A button you place', 'Feature switches', 'Fewer ads'], 'INSIDE ALBRHI'),
 ('tiktok', 'tiktok', 'Albrhi for TikTok', 'زر تحميل في الفيد وخصوصية أكثر', 'A download button in the feed, photo posts, privacy.', ['Download button', 'Photo posts', 'No ads', 'Privacy'], 'INSIDE ALBRHI'),
 ('ytmusic', 'youtube-music', 'Albrhi for YouTube Music', 'كلمات متزامنة وحفظ الأغاني', 'Synced lyrics, saving tracks, no ads.', ['Synced lyrics', 'Save tracks', 'No ads', 'Background play'], 'INSIDE ALBRHI'),
 ('panel', 'panel', 'Albrhi Panel', 'كل شي من مكان واحد في الإعدادات', 'Settings › Albrhi: a switch per app, a guide, backup.', ['A switch per app', 'A guide', 'Backup', 'Off until you turn it on'], 'INSIDE ALBRHI'),
 ('spotify', 'spotify', 'Albrhi for Spotify', 'بدون إعلانات ولا مقاطع ممولة', 'No ads, no Premium pop-ups, sponsored podcast parts skipped.', ['No ads', 'No pop-ups', 'Podcast SponsorBlock', 'Swift and Orion'], 'NOT PUBLISHED'),
 ('nextup', 'nextup', 'Albrhi NextUp', 'شوف وش يشتغل بعده من شاشة القفل', 'See and skip what plays next, from the Lock Screen.', ['What plays next', 'Lock Screen', 'Five media apps', 'A GPLv3 port'], 'OWN PACKAGE'),
 ('watch', 'watch', 'Albrhi Watch', 'اربط ساعة بنظام أحدث من جوالك', 'Pair an Apple Watch running a newer watchOS.', ['Newer watchOS', 'Pairing gate', 'Update hold', 'An MIT port'], 'OWN PACKAGE'),
]
os.makedirs(os.path.join(OUT, 'cards'), exist_ok=True)
for slug, page, title, ar, en, feats, badge in TWEAK_CARDS:
    top = glow = ACC[slug]
    chips = ''.join('<span style="display:inline-block;margin:0 12px 12px 0;padding:10px 20px;border-radius:99px;background:rgba(255,255,255,.09);border:1px solid rgba(255,255,255,.18);color:#fff;font-size:23px;font-weight:600">%s</span>' % f for f in feats)
    bcol = '#7CF2B3' if badge in ('INSIDE ALBRHI', 'THE FRONT DOOR') else ('#FFC76A' if badge == 'NOT PUBLISHED' else '#9CC7FF')
    html = ('<!doctype html><meta charset="utf-8"><style>%s</style><body style="width:1600px;height:560px;position:relative;overflow:hidden;color:#fff;'
            'background:radial-gradient(760px 520px at 88%% 40%%,%s55,transparent 70%%),radial-gradient(640px 420px at 6%% 0%%,%s33,transparent 70%%),linear-gradient(160deg,#08140f,#04100a 55%%,#020a06)">'
            '<div style="position:absolute;inset:0;opacity:.06;background-image:radial-gradient(#fff 1.2px,transparent 1.4px);background-size:34px 34px"></div>'
            '<img src="../icons/%s.png" style="position:absolute;right:-70px;top:-10px;width:620px;height:620px;border-radius:146px;opacity:.20;transform:rotate(-12deg);filter:blur(1px)">'
            '<img src="../icons/%s.png" style="position:absolute;left:92px;top:96px;width:232px;height:232px;border-radius:54px;box-shadow:0 0 90px %s88,0 22px 56px rgba(0,0,0,.55)">'
            '<div style="position:absolute;left:372px;top:80px;width:1100px">'
            '<div style="font-size:78px;font-weight:800;letter-spacing:-3px;line-height:1.04">%s</div>'
            '<div style="font-family:\'SF Arabic\',\'Geeza Pro\',-apple-system,sans-serif;font-size:42px;font-weight:700;color:%s;margin-top:14px;direction:ltr">%s</div>'
            '<div style="font-size:29px;color:rgba(255,255,255,.76);margin-top:12px;font-weight:500">%s</div></div>'
            '<div style="position:absolute;left:92px;top:388px;width:1300px">%s</div>'
            '<div style="position:absolute;right:70px;top:54px;padding:8px 18px;border-radius:99px;border:1.5px solid %s;color:%s;font-size:17px;letter-spacing:2.6px;font-weight:700;background:rgba(0,0,0,.25)">%s</div>'
            '<div style="position:absolute;left:92px;bottom:30px;font-size:19px;color:rgba(255,255,255,.5);font-family:ui-monospace,Menlo,monospace">ibrahim2100.github.io/albrhi-repo</div></body>'
            ) % (CSS, glow, top, slug, slug, glow, title, top, ar, en, chips, bcol, bcol, badge)
    render(html, os.path.join(OUT, 'cards', page + '.png'), 1600, 560)
    print('card', page)

# web copies for the Sileo depiction headers: 1200 wide JPEG, published as cards/<slug>.jpg (the card for a package id is named in brand/catalog.json)
web = os.path.join(OUT, 'cards-web'); os.makedirs(web, exist_ok=True)
for slug, page, *_ in TWEAK_CARDS:
    subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '82', '--resampleWidth', '1200',
                    os.path.join(OUT, 'cards', page + '.png'), '--out', os.path.join(web, slug + '.jpg')], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print('cards-web')
