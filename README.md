<div align="center">

# Albrhi · البرهي

### iOS tweaks, built in the open — bilingual, native, and written to be read

**العربية · English** · a working APT source · nine tweaks, six in one package

[![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2015%2B-lightgrey.svg)](#-compatibility)
[![Rootless](https://img.shields.io/badge/rootless-supported-success.svg)](#-compatibility)
[![roothide](https://img.shields.io/badge/roothide-supported-success.svg)](#-compatibility)

[![Albrhi](https://img.shields.io/badge/Albrhi-1.88.0-blueviolet.svg)](suite/CHANGELOG.md)
[![Instagram](https://img.shields.io/badge/Instagram-4.5.0-orange.svg)](tweaks/instagram/CHANGELOG.md)
[![YouTube](https://img.shields.io/badge/YouTube-1.37.0-red.svg)](tweaks/youtube/CHANGELOG.md)
[![X](https://img.shields.io/badge/X-0.19.1-black.svg)](tweaks/twitter/CHANGELOG.md)
[![TikTok](https://img.shields.io/badge/TikTok-0.20.3-ff0050.svg)](tweaks/tiktok/CHANGELOG.md)
[![YT Music](https://img.shields.io/badge/YT%20Music-0.9.3-FF0000.svg)](tweaks/ytmusic/CHANGELOG.md)
[![Spotify](https://img.shields.io/badge/Spotify-0.2.5-1DB954.svg)](tweaks/spotify/CHANGELOG.md)
[![Panel](https://img.shields.io/badge/Panel-0.9.38-8E8E93.svg)](tweaks/panel/CHANGELOG.md)
[![NextUp](https://img.shields.io/badge/NextUp-0.3.1-FF375F.svg)](tweaks/nextup/CHANGELOG.md)
[![Watch](https://img.shields.io/badge/Watch-0.6.1-FF375F.svg)](tweaks/watch/CHANGELOG.md)
[![Based on](https://img.shields.io/badge/based%20on-SCInsta-lightblue.svg)](https://github.com/SoCuul/SCInsta)

<br/>

### 📦 Add the source to your package manager

**`https://ibrahim2100.github.io/albrhi-repo/`**

[![Add to Sileo](https://img.shields.io/badge/Add%20to-Sileo-2C7CF0?style=for-the-badge&logo=apple&logoColor=white)](https://sharerepo.stkc.win/?repo=https://ibrahim2100.github.io/albrhi-repo/)
[![Add to Zebra](https://img.shields.io/badge/Add%20to-Zebra-D4462D?style=for-the-badge&logo=apple&logoColor=white)](https://sharerepo.stkc.win/?repo=https://ibrahim2100.github.io/albrhi-repo/)

<sub>Lower case, exactly as written — GitHub Pages paths are case sensitive.</sub>

</div>

---

## Contents

[Install](#-install) · [Licence](#-licence) · [What is in here](#-what-is-in-here) ·
[Instagram](#-albrhi-for-instagram) · [YouTube](#-albrhi-for-youtube) · [X](#-albrhi-for-x) ·
[TikTok](#-albrhi-for-tiktok) · [YouTube Music](#-albrhi-for-youtube-music) ·
[Spotify](#-albrhi-for-spotify) · [Panel](#-albrhi-panel) · [NextUp](#-albrhi-nextup) ·
[Watch](#-albrhi-watch) · [Compatibility](#-compatibility) · [Sideloading](#-sideloading) ·
[Building](#-building) · [Usage](#-usage) · [How it is made](#-how-it-is-made) ·
[Roadmap](#-roadmap) · [Credits](#-credits)

---

## ⚡ Install

**There is one package to install: `com.albrhi`, listed as *Albrhi*.** It carries the Instagram,
YouTube, X, TikTok and YouTube Music tweaks and the Settings panel together — one thing to install,
one thing to update, and a new tweak arrives inside it rather than as a second download.

**1 · Add the source** — tap a button above, or **Sileo / Zebra → Sources → ＋** and paste:

```
https://ibrahim2100.github.io/albrhi-repo/
```

**2 · Install** *Albrhi*, then **respring**. The source serves both flavours and your package manager
picks the right one:

| Package | For |
|---|---|
| `com.albrhi` | Rootless (Dopamine, palera1n) |
| `com.albrhi.roothide` | roothide |

The two `Conflict`/`Replace` each other, so only one is ever active. What makes a package roothide is
its *paths*, not its control file — they are genuinely different builds, not one relabelled.

**3 · Choose what it patches.** **Settings → Albrhi** lists every app with a switch each. The switches
start **off**: installing Albrhi must never silently patch four apps nobody asked about. Turn one off
again and the package stays installed with its settings intact; reopen that app for it to take effect.

**4 · Activate.** See [Licence](#-licence) — there is a free week, taken from that same screen.

<details>
<summary><b>Other ways to install, and what is not served any more</b></summary>

<br/>

- **From a GitHub release** — download the `.deb` for your setup from the
  [Releases page](https://github.com/ibrahim2100/albrhi-repo/releases).
- **Sideloading (no jailbreak)** — see [Sideloading](#-sideloading).
- **From source** — see [Building](#-building) and [BUILD.md](BUILD.md).

**The individual packages (`com.albrhi.tweak`, `com.albrhi.youtube`, …) are no longer served.** They
were frozen at whatever version they last published and could never update, because nothing
publishes them any more. `com.albrhi` declares `Conflicts`/`Replaces` on all of them, so a device
cannot hold both; if you installed one before, installing the suite removes it for you.

</details>

---

## 🔑 Licence

Albrhi needs a licence to run. Open **Settings → Albrhi → Licence**:

| | |
|---|---|
| **A free week** | Taken from that screen, once per device, starting the moment you take it. |
| **A key** | Bound to your device. Works with no network at all — the signature is checked on the phone. |
| **A short code** | Like `ALB-4K7M-9QX2-P3RT`. Typed in, redeemed once, then bound to your device. |
| **A request** | Makes a short message carrying your device, the term you want and your name; you send it, and the answer comes back as a key. |

A licence renews itself quietly in the background (about once a day, and never in a way that can
hold up a launch). A licence that has been **withdrawn stops working within a day**; a phone in
airplane mode or behind a captive portal loses nothing, because a failed check means *nothing was
decided*, never *not licensed*.

- **The panel itself is never behind the licence**, so the screen that lets you back in is always
  reachable.
- **When a tweak stands down because of the licence, the panel says so** — switches that read ON while
  nothing happens would be a screen lying to you.
- **Nothing identifying is read from your phone.** The device id is a random value the panel writes
  once; it is derived from nothing about you or the hardware.
- No client-side check can be made unbreakable, and this one is not sold as one: what it buys is that
  most people never crack anything, and that a leaked key can be revoked. The design and its honest
  limits are written out in [docs/LICENCE-KEYS.md](docs/LICENCE-KEYS.md).

---

## 🧭 What is in here

**Albrhi** is a personal workshop for iOS tweaks that is also a working APT source: it builds itself,
publishes its own releases, and serves a Sileo/Zebra repository from GitHub Pages. It is written for
learning as much as for using — the code is commented to explain *why*, and the reasoning behind the
awkward parts is kept in [CLAUDE.md](CLAUDE.md) rather than lost.

Developed by **Ibrahim Ismail AL-Rahn** ([@ibrahim2100](https://github.com/ibrahim2100)).

**Nine tweaks. Six ship inside `com.albrhi`; three stand on their own.**

| Tweak | Patches | Version | In `com.albrhi` | What it does |
|---|---|---|:-:|---|
| **[Instagram](#-albrhi-for-instagram)** | Instagram | 4.5.0 | ✅ | downloads, AV1 reels transcoded on the device, a quieter feed, watching stories without a receipt, unsent messages kept and marked |
| **[YouTube](#-albrhi-for-youtube)** | YouTube | 1.37.0 | ✅ | downloads that survive app updates, their own Download Centre tab, no ads, SponsorBlock, background playback |
| **[X](#-albrhi-for-x)** | X / Twitter | 0.19.1 | ✅ | media downloads with a button you can place yourself, and fifteen-plus switches for what X does |
| **[TikTok](#-albrhi-for-tiktok)** | TikTok | 0.20.3 | ✅ | a download button in the feed, photo posts, no ads, confirmations, privacy |
| **[YouTube Music](#-albrhi-for-youtube-music)** | YouTube Music | 0.9.3 | ✅ | synced lyrics, saving tracks, no ads, background playback |
| **[Panel](#-albrhi-panel)** | Settings | 0.9.38 | ✅ | the Albrhi page: a switch per app, the licence, a guide, backup |
| **[Spotify](#-albrhi-for-spotify)** | Spotify | 0.2.5 | — | no ads, no Premium popups, sponsored podcast segments skipped |
| **[NextUp](#-albrhi-nextup)** | SpringBoard + five media apps | 0.3.1 | — | what plays next, on the Lock Screen — a GPLv3 port |
| **[Watch](#-albrhi-watch)** | SpringBoard, Watch app | 0.6.1 | — | pair a newer watchOS than iOS expects, and hold watchOS 26 back — an MIT port |

Each is a self-contained Theos project under `tweaks/` with its own sources, package identity and
version, and **they never meet at runtime**: an injection filter binds each dylib to one bundle id, so
the YouTube tweak is never loaded into Instagram. What they share is the build plumbing — the checks,
the build script, the licence layer and the APT index.

`com.albrhi` is built by `tools/make-suite.sh`, which picks up every `tweaks/*/control` automatically.
A tweak stays out of it only by carrying a `.no-suite` marker — Spotify, NextUp and Watch do.

> Albrhi is an **educational and corrective derivative** of [SCInsta](https://github.com/SoCuul/SCInsta)
> by **SoCuul**, developed with AI assistance to improve code quality, design, performance and user
> experience — while fully respecting the original project, its authors and its licence. Original
> authorship is credited in-app, in this README, in the package metadata and in the source headers.

<details>
<summary><b>Tweaks that used to be here</b></summary>

<br/>

**Albrhi for Locket** was removed on the owner's instruction to isolate it completely: it left the
suite first, then the project. **Albrhi CarPlay** was removed because it patched SpringBoard and Camera
and never ran on a device — it is going to be rebuilt from scratch in a repository of its own, since a
wrong hook there takes the home screen with it. Both keep their releases on the releases page as
history, and the source no longer serves them: deleting a tweak does not stop an index built from
published releases from offering it, so their package names are named in `WITHHELD_PACKAGES`.

</details>

---

## ✨ Albrhi for Instagram

### 📥 Downloads
- One-tap **download button** in the post and reel action rows — posts, reels, stories, **whole
  albums** (one slide or all), DM media and **HD profile pictures**.
- Always the best quality your iPhone can save. Some of Instagram's higher qualities come in a format
  iOS will not play; Albrhi converts those **on your phone**, keeping the HDR. Nothing is uploaded.
- **Download Center** — queue, pause, resume, retry, background transfers and history.
- Reel audio extraction · silent-video export · a dedicated Photos album.
- Stories (including a video story and a music-over-photo story) save as what they are, not as their
  poster frame.

### ✉️ Stories & Messages
- **Watch stories with no seen receipt.** The eye button still marks one as seen when you want it to.
- **Unsent messages stay.** When the other person takes a message back, it stays in the chat and gets
  a **red trash badge**, so you can tell which ones were taken back. *Confirmed on Instagram 410.*
  A **deleted-messages log** (Settings › Messages) keeps what each one said, who sent it and when — it survives the refresh that clears them from the chat.
- Hide your **"Active now"** status (experimental) · hide the typing indicator · save DM photos and
  videos, even view-once, with per-message mark-as-seen · full last-active time as a real date ·
  hide the voice and video call buttons · replay visual messages · disable screenshot detection.

### 🧹 Feed, Explore & Reels
Hide ads, sponsored and suggested posts · suggested users, reels and Threads posts · the stories tray ·
the entire feed · the explore grid · trending searches · the friends map · Meta AI · video autoplay.
Reels: tap-to-pause or mute · an always-on scrubber · auto-advance · anti doom-scrolling · hide the
header and blend button · refresh confirmation.

### 🔒 Confirmations
Optional prompt before like, follow, repost, call, voice message, follow-request response, Shh mode,
comment, chat-theme change, story-sticker tap and **chats refresh** (always asked while unsent messages are being kept, since a refresh removes them) — so a mis-tap never becomes a notification.

### 🎨 Appearance & profile
Custom **date & time formats** everywhere Instagram writes a time · **OLED black** · a custom accent
colour · a **follow-back badge** under the followers count (green *follows you* / red *doesn't*) · copy
account info.

### 🛠️ Interface
Native inset-grouped settings with **search** · **backup & restore** to a file · copy any text by
long-press · full dark mode · Arabic/English with RTL · tab ordering, hiding and swipe-between-tabs ·
a **Diagnostics** page that reports what actually attached at runtime, scans the live view hierarchy,
and files an issue with the whole report in one tap.

---

## ▶️ Albrhi for YouTube

### 💾 Save a video — and keep saving it after YouTube updates
Tap YouTube's **own download button** under a video (Shorts get a save button of their own, beside
like and share). A sheet offers the qualities and, separately, **sound only**, which is saved as a
proper `.m4a` with the video's cover art. It lands in the Download Centre with a percentage.

**How it gets the file changed in 1.34.0, and the reason is resilience.** YouTube no longer hands the
app file links, so anything read *out of the app* breaks whenever the app changes. Albrhi now asks
YouTube **itself**, as a client that is still served plain files (the *direct route*, the method
[YTKACE](https://github.com/itzzace/ytkace) documents), fetches the file in 8 MB pieces in parallel,
checks that every byte YouTube declared arrived, and assembles the `.mp4` **without FFmpeg and without
re-encoding**.

- **It is anonymous.** No cookie, no account, no login — only a visitor id YouTube gives anyone who asks.
- **The trade:** a video that needs an account (age-restricted, private, members-only) is refused
  there, and the download falls through to the **playlist route**, which carries the app's own session.
  A video that fails once is not asked about twice in a session.
- **What it offers:** H.264 up to **1080p**, and AAC. 1440p and 4K come from YouTube only as AV1 (and
  VP9), which most iPhones cannot play — so they appear only behind a switch (**Offer 1440p and 4K**,
  off by default), are saved untouched as an `.mp4`, and say what they need: VLC, Infuse, a Mac, or an
  iPhone 15 Pro and later. A second, optional switch (**Convert AV1 to HEVC while saving**) decodes
  the AV1 in software and re-encodes it, so an older iPhone plays the file — in Photos too. It takes minutes
  and the app has to stay open; if it cannot finish, the AV1 file is saved as it is. An AV1 file is never
  sent to Photos.
- **The remux is our own**, because AVFoundation was measured reading these fragmented files with every
  timestamp doubled (a 19-second clip reporting 37.9). The boxes are read directly and the frames are
  written with their own timestamps. Checked on a 19 s clip, a 3:33 song and a 10:35 1080p60 film.

### 📁 The Download Centre
A **tab of its own**, beside Home and You — not a panel over the app. YouTube draws the tab itself, so
it has a real label, a real selected state and its share of the width. Inside: everything you have
saved, video and audio, in a player written for the job — landscape fills the screen, double-tap to
jump ten seconds, **picture in picture**, speed, a sleep timer, AirPlay, and it remembers where you
stopped, days later and across restarts. A **mini bar** keeps the sound going while you browse; the
lock screen gets the artwork, a draggable scrubber, and next/previous through your own list. Rename,
share, or send anything to Photos. Simultaneous downloads are a setting.

### 🗂️ Arrange the tab bar
**Settings › Interface › Tab bar** — drag to reorder, drag across to switch a tab off, hide the `+`,
and add **History** as a tab. The bar holds six; one screen enforces that for everything at once.
Every decision is made on a tab's identifier, never its position.

### 🚫 No ads
Blocked where they arrive — the app stops asking for them, promoted rows are dropped from the feed
(through all three doors the feed fills by, so a pull-to-refresh cannot bring one back), and the player
refuses ads before, during and inside a video. Extra gates for the player response, the Shorts list and
subscription pop-ups are installed at runtime **only where the running build declares them**, and each
one counts its own hits in the report.

### ⏭️ SponsorBlock, background playback, and the rest
- **Skip the sponsored parts** using segments other viewers submitted. A short line names what was
  skipped and offers an undo; each segment is **coloured on the progress bar**. Eight categories, each
  with a switch. **Which video you are watching is never sent** — the private lookup is used.
- **Background playback** for YouTube's own video and anything you saved.
- **Playback-error recovery.** The "an error occurred" screen reloads the player and resumes from the
  same second — with a budget of three reloads per video, so a video that truly cannot play is handed
  back to YouTube's own error rather than looped forever.
- **A quality ceiling** separately for Wi-Fi and mobile data, plus the full quality list.
- Silence the update prompt (updating would remove the tweak).

### ⚙️ Settings & diagnostics
**Hold two fingers anywhere.** Arabic and English with RTL, and a card saying whether everything
attached to *your* build. **The report is written when you ask for it** (Settings › General), plus once
if the launch guard has to step in — nothing writes itself on every launch, and a file that can grow has
a 1 MB ceiling. **A launch guard** stands the expensive hooks down if the app has not become active
eight seconds after the tweak loaded, and says so: a tweak may cost a feature, never the app.

> Hooked on YouTube's **model and service layer, never its views** — view classes get renamed between
> releases and a tweak that hooks them quietly stops working.

---

## 🐦 Albrhi for X

### 💾 Save anything
**Hold any photo or video**, or use the **button on the video itself**. One capture point serves the
timeline, full screen, quoted posts and DMs, because all four build the same media model. The in-video
button is **yours to place**: drag it, pin it, and it stays put on every card and every device — stored
as a fraction of the room it has, never as points, so it cannot walk off screen.

### 🎛️ What X does, under your control
X asks one place what the app may do, and Albrhi records every question it is asked — so the Switches
page is built from **your own use**, not a table copied from elsewhere — with named features on top.
Among them:

- **No ads, Promote button, Grok, Premium nags**, less tracking, a faster launch.
- **Links:** copied `x.com` links lose the `s` and `t` parameters, a `t.co` can show where it really
  goes, links can open in **Safari**.
- **Between the posts:** hide who-to-follow, topics and trend videos, **Spaces** (hidden, never forbidden —
  a Space somebody sends you still opens), view counts and the bookmark button.
- **Privacy:** no search history (queries *and* accounts, refused at the write), X behind **Face ID**
  with the cover up before the prompt.
- **A post as a picture** (long-press share), correctly laid out for right-to-left and not mirrored.
- Ask before a like or a follow — never before an unlike or an unfollow. Communities and Profile tabs
  in the bottom bar.

**`app_attest_*` is deliberately not offered.** Those keys are how X proves to its servers that the
device is unmodified; answering them falsely is an account risk, not a privacy setting.

**Hold two fingers anywhere** for settings.

---

## 🎵 Albrhi for TikTok

### ⬇️ A download button in the feed
A blurred disc with a down arrow, **above the profile picture** on every video, riding with TikTok's own
rail. It saves the clip you are **watching**, because the video is read from the controller the button
sits inside at the moment you tap it.

Quality is **measured, not guessed**: every link TikTok offers is collected and weighed by what it
actually is — a watermarked copy loses to a clean one, audio loses to video, and only then does size
decide. Optionally HD can be fetched from an outside service; **that switch is off and stays off until
you turn it on**, with its cost written on its own row (it tells that service which video you are
watching).

### 🖼️ Photo posts · 📅 the publish date · 💬 comments
- **Photo posts save as photos**, and it **asks first**: the picture you are on, or all of them. A
  single picture can also be saved **as a short video with the post's own sound**.
- **The publish date** sits above the download button — the day, the month by name, the year, and the
  time beneath.
- **Save media from a comment** — a *Save* row in TikTok's own long-press sheet when a comment carries
  a picture, sticker or animation.

### 🚫 Ads · ✋ Confirmations · 🔒 Privacy
An item TikTok's own server marked as an ad is refused as the object is built — and the launch splash
ad with it. Ask before a like or follow (off until you turn it on; if the question cannot be shown, the
tap goes through rather than "liking is broken"). **Three separate privacy switches** — a story's seen
mark, a message's read receipt, a profile view — because they are three different reports to three
different places. What shows on your own screen is never touched.

### 🧩 Extras
More logged-in accounts · **messages taken back stay visible and are marked as such** · a record of
profile visitors, kept as TikTok delivers them · the seek bar kept visible · the jailbreak answered for
as an unmodified phone would.

### 🎛️ The settings screen
Rebuilt in 0.20.0: an identity card, a two-column grid of categories, and a card per option with an icon,
what it does, and its switch. The full diagnostic report is one row away and copyable in a tap. **Hold
two fingers anywhere.**

---

## 🎼 Albrhi for YouTube Music

- **🎤 Synced lyrics**, with the current line lifted out. Six sources are asked and the best answer wins
  (LRCLib, Genius, MusixMatch, NetEase, the video description, YouTube Music's own); a wrong match is
  discarded rather than shown. CJK romanisation, selectable text, a pinned source, timing nudges, and
  optional translation with a key you supply yourself.
- **💾 Save a track** through the download button YouTube Music already draws — without FFmpeg — with a
  **Downloads tab** where the Upgrade tab used to be, and a player that behaves like the app's.
- **🚫 No ads**, the Premium advertisement and Upgrade tab hidden, **background playback** without the
  upsell notification, **no autoplay radio**, casting, and a true-black theme.
- **The speed control the app already has and hides**, seek buttons, and **SponsorBlock** for the one
  category a music app has (`music_offtopic`, off until you switch it on).

> A lyrics feature asks outside services what is playing. There is no version of it that does not — it is
> on because it was asked for by name.

**This does not unlock Premium.** The tweaks these hooks come from tell YouTube Music the account is a
paying one; that is the single thing not carried over.

**Verified, not only compiled:** `tweaks/ytmusic/tests/host/run.sh` runs the pure-logic parts (LRC parser,
matching pipeline, caches, romaniser, extractors) on the build machine in about a second.

> **The hooks are not this project's work.** They are
> [YTMusicUltimate](https://github.com/dayanch96/YTMusicUltimate) by **dayanch96** and
> [YTMEnhanced](https://github.com/py233/YTMEnhanced) by **py233**, both GPLv3 — the licence Albrhi ships
> under, which is what makes carrying them over lawful. Every ported file is kept diffable against
> upstream, with each edit written where it is.

---

## 🎧 Albrhi for Spotify

**No ads — and no Premium.** Audio and display ads are refused where Spotify asks for them, the home
feed's sponsored rows are filtered out of the JSON before the screen is built, and the "go Premium"
popups are dropped as they are presented.

**This does not unlock a paid subscription.** It does not touch your account, does not report you as a
subscriber, and does not raise the audio quality — those are account attributes the server decides, not
switches inside the app. The settings page says so above its own switches.

**Sponsored segments in podcasts** are skipped from SponsorBlock's database, with a note saying which
one. **Off until you turn it on:** it asks a third-party server about what is playing.

Written in **Swift and Orion**, the only tweak here that is. That costs things a Logos tweak does not:
the constructor is not called for you, a hook group must be activated behind a check that its target
exists, and SwiftUI cannot be compiled against the pinned SDK at all.

> **The ad blocking and SponsorBlock are not this project's work.** They are
> [EeveeSpotify](https://github.com/SideloadLabs/EeveeSpotifyReincarnated) by **Eevee** and the
> **SideloadLabs** team, under GPLv3. Every ported file is kept diffable against upstream; Albrhi adds the
> gate, the settings page and the bilingual interface.

---

## 🎛️ Albrhi Panel

**Settings › Albrhi.** The front door.

- **A switch per patched app**, opt-in, and a page for each tweak that has more to say than a switch.
- **One master switch above all of them.** When an app update breaks something, it stands every Albrhi
  tweak down on the next launch **without changing a single setting below it**.
- **The licence** — device, term, scope, where it came from, every app it is running in with its version
  and when it was last seen. See [Licence](#-licence).
- **A guide built from the device:** every tweak on *this* phone, what it does, the app version it was
  verified against and the version actually installed — built from the same scan as the main page, so it
  cannot describe a tweak that is not there.
- **Your settings, out and back** through the share sheet (a file written beside the preferences it
  copies would be destroyed by the very event it exists for). What it holds is stated; a file that is not
  ours is refused whole.
- **An update check, on a tap** — never on page load — that asks Albrhi's own source and keeps *could not
  be reached* distinct from *you are up to date*.

---

## ⏭️ Albrhi NextUp

A row under the now-playing controls — the next track's title, artist and cover — on the **Lock Screen**,
in **Control Center** and in the **Dynamic Island**. Tap the cover to play it now, or skip it, without
opening the app that is playing.

| App | Support |
|---|---|
| **Apple Music** | Full |
| **Apple Podcasts** | Full |
| **YouTube Music** | Full — built against **9.28.4** |
| **YouTube** | Full — built against **21.32.4**. A playlist has a real queue; a standalone video shows YouTube's own autoplay suggestion, which is playable but not skippable |
| **Spotify** | Full — built against **9.1.62** |
| **SoundCloud** | Added with NextUp 3 1.2 |

Each row shows what that app itself would play next, read from its own queue — not a guess. The version
beside an app is the build its reader was written against; when a row goes blank after an update, that
number is the first thing to check.

**Settings › Albrhi › Albrhi NextUp** — a master switch, one per surface, one per app. Changes apply
immediately. **The master is off until you turn it on** (this port's own change), since it injects into
SpringBoard and five media apps. The log is compiled in and **off by default**, with a 128 KB ceiling per
process.

> **A port, not an original.** Albrhi NextUp is [NextUp 3](https://github.com/Yves000/NextUp3) by **Yves**,
> under the GNU GPL v3. The design, the private-API research and very nearly all of the implementation are
> Yves's work; this port replaced the Settings pane with a page of its own and rebranded the package.
> [Its changelog](tweaks/nextup/CHANGELOG.md) lists every change rather than letting it read as original.

> **It injects into SpringBoard.** A wrong hook there takes the home screen with it — have a way back in
> (SSH, or a package manager reachable from safe mode) first. On a jailbreak with per-app injection, the
> media apps need injection enabled too, or the row stays empty.

---

## ⌚ Albrhi Watch

**Pair a watch iOS does not expect.** iOS refuses to pair with an Apple Watch whose watchOS is newer than
it expects. Watch answers those compatibility questions the way a supported pairing would — the pairing
gate, the declared capabilities, the companion-app runtime check — so setup completes and apps install.
*Confirmed on a device.*

**Hold watchOS 26 back** — a **filter, not a blanket refusal**: the version is read from the update
itself, so watchOS 26 and newer is withheld while security updates for the version your watch is on are
still offered. An update whose version cannot be read is let through. Nothing can start a held update: the
scan result, the install button's two actions, the download and the installation are each refused
separately — and **the Software Update page says Albrhi is the reason**, and names the switch that undoes
it, instead of iOS saying "up to date" in a sentence the tweak caused.

**Settings › Albrhi › Albrhi Watch.** The master is off until you turn it on. A pairing change is applied by
a **full userspace restart**, not a respring — measured on a device.

> **The pairing core is not this project's work.** It is [watched](https://github.com/34306/watched) by
> **34306**, under the MIT licence — carried over as code, with its notice shipped inside the package.

> **It injects into SpringBoard.** Have a way back in before installing any build.

---

## ⚠️ Instagram and roothide Bootstrap

**On [roothide Bootstrap](https://github.com/roothide/Bootstrap), Instagram 442 and newer crashes when you
change your profile picture. It is not caused by Albrhi, and no version of Albrhi can fix it.**

That reads like every tweak author blaming the loader, so here is how it was established. The fault was cut
in half, then in half again: every feature removed — **crash**; every hook installed with every setting
answering false — **crash**; a dylib of **one file that logs a line, no hooks, no classes, no load-time
work** — **crash**; the same tweak merged by hand into the app with no jailbreak injecting it — **no crash**.
An empty 128 KB library is enough, and the identical code injected differently does not crash at all.

**What you can do:** turn Albrhi off for Instagram while changing a picture, or use a manually merged build.

---

## 🧩 Compatibility

| | |
|---|---|
| **iOS** | 15.0 and later (NextUp 14.2–26) |
| **Architecture** | `arm64` and `arm64e` |
| **Jailbreaks** | Rootless (Dopamine, palera1n) · roothide · rootful (unc0ver, checkra1n) |
| **Instagram** | Tested on **410, 439 and 441**, from one build |
| **YouTube** | Tested on **21.30.5** (the direct route does not depend on the app version) |
| **X / Twitter** | Tested on **12.15** |
| **TikTok** | Tested on **46.4.0** |
| **NextUp** | Confirmed on **16.1** — Music, Podcasts, YouTube **21.32.4**, YT Music **9.28.4**, Spotify **9.1.62** |
| **Watch** | Any watchOS the pairing gate is asked about |

> The tested versions are the newest builds the developer's own phone accepts. They are not a ceiling:
> nothing is pinned to a version number, every class is looked up at runtime, and anything absent is
> skipped rather than crashed on. If one is not found, the **Diagnostics** page shows what the tweak can
> actually see on your phone and reports it in one tap.

---

## 📲 Sideloading

Instagram, YouTube, X and TikTok are also built as **standalone dylibs** (`Albrhi*.dylib`) attached to each
release, for injecting into a decrypted IPA with LiveContainer, Sideloadly or cyan — or with
`tools/ipa-inject.html` in a browser. Each carries **its own licence page** in its own settings, because a
sideloaded build has no Settings panel to enter a key in. A dylib and the suite can never be injected
twice: the suite declares `Conflicts`/`Replaces` on them.

---

## 🔨 Building

Requires [Theos](https://theos.dev) with an iOS SDK (the pinned **iPhoneOS 16.2**), GNU `make`, `ldid`
and `dpkg`.

```bash
git clone https://github.com/ibrahim2100/albrhi-repo.git
cd albrhi-repo
git submodule update --init --recursive
export THEOS=$HOME/theos
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"   # GNU make; Apple's fails Theos

python3 tools/check.py            # always first — seconds, not a five-minute compile
./build.sh youtube rootless       # result lands in tweaks/youtube/packages/
```

Swap `youtube` for `instagram`, `twitter`, `tiktok`, `ytmusic`, `spotify`, `panel`, `nextup` or `watch`,
and `rootless` for `roothide`, `rootful` or `sideload`. **roothide needs a second Theos** (the roothide
fork) — the flavour is chosen by which Theos stages the package, never by the control file:

```bash
tools/build-local.sh                # the whole suite, roothide, onto ~/Desktop/Albrhi
tools/build-local.sh youtube rootless
```

It proves the flavour from the staged paths rather than the filename, and refuses to copy out a mismatch.
See [BUILD.md](BUILD.md) and [GITHUB_BUILD.md](GITHUB_BUILD.md) for CI.

**Pure logic is run, not only compiled.** The YouTube Music lyrics module and the YouTube transport layer
build against the macOS SDK and execute on the build machine:

```bash
bash tweaks/ytmusic/tests/host/run.sh
bash tweaks/youtube/tests/host/run.sh
```

A hook needs a device and there is no way around that. A parser does not.

### Layout

```
tweaks/<app>/     a complete tweak: Makefile, control, filter plist, src/, CHANGELOG.md
suite/            com.albrhi — the combined package, and the preinst that clears the old ones
shared/           Theos flags, build modes, the panel gate and the licence layer every tweak shares
server/           the licence server (a Cloudflare Worker)
app/              the owner's native admin app for that server (Theos, TrollStore)
licence/          published code hashes and the revocation list
docs/             LICENCE-KEYS.md — how keys are issued and what they do and do not promise
tools/            source checks, APT index, depictions, signing, .deb editing, the browser tools
modules/ vendor/  third-party code, shared
extra-debs/       drop a .deb here and the source publishes it
```

Adding a tweak means adding a directory under `tweaks/` — `tools/check.py` finds it, `./build.sh <name>`
builds it, and `make-suite.sh` pulls it into `com.albrhi` automatically. Staying out takes a `.no-suite`
marker, and a tweak with nothing to do with the suite gets a publishing workflow of its own.

### 🧰 The tools

Everything under `tools/` is meant to be run by hand as well as by CI.

| | |
|---|---|
| **`check.py`** | **Twenty-four source checks**, run before Theos. Every rule comes from a build or a device that actually broke — unbalanced `%hook`/`%end`, a hooked class touching `self` without an `@interface`, a fragile `%orig`, a missing localisation key, a `%new` parameter carrying an attribute, and `-valueForKey:` probing (which runs the app's own code and cannot be made safe by `@catch`). Run from the root it re-runs itself once per tweak. |
| **`objc-classes.py`** | Prints a class's real methods, **declared property types**, ivars and **type encodings** straight out of a Mach-O's ObjC metadata; `--find-method` / `--find-ivar` answer "who answers this selector / owns this field". A framework-wide selector dump says a name *exists*, never on which class — this project lost releases to that gap. |
| **`make-suite.sh`** | Merges every tweak without `.no-suite` into `com.albrhi`, and refuses a staged tree that does not match the scheme it was asked for. |
| **`make-repo.sh`** · **`fetch-published-debs.sh`** | Build the APT index **from the published releases** (so several workflows can rebuild one index safely), with an explicit `WITHHELD_PACKAGES` list — because building the index from releases means silence removes nothing. |
| **`make-depiction.py`** | Sileo depiction and HTML fallback generated **from the changelog**, so they cannot go stale. |
| **`licence.py`** · **`licence-panel.html`** · **`build-store.sh`** | Issue and revoke licences; build a one-shop copy. |
| **`inject-dylib.py`** · **`ipa-inject.html`** | Put a dylib into an IPA, with entitlements read first and handed back. |
| **`deb-edit.py`** · **`deb-edit.html`** | Edit `.deb` metadata from a terminal or browser (served at `…/deb-edit/`). |
| **`build-local.sh`** · **`build-dylibs.sh`** · **`build-dav1d.sh`** | Local suite builds, the standalone dylibs, and the AV1 decoder. |
| **`release-notes.py`** · **`make-logo.py`** · **`repo-index.html`** | Release bodies from a changelog, the repo icon in pure Python, and the landing page. |

---

## 📖 Usage

**Instagram** — **hold the ☰ button** at the top right of your profile (with *Settings quick-access* on,
holding the **home tab** works too). Download with the inline button; long-press a post to zoom; search any
setting from the bar at the top.

**YouTube** — **hold two fingers anywhere.** It is deliberately not in YouTube's own settings: two attempts
at that crashed the app, because a settings entry must satisfy tables the tweak cannot reach. Tap YouTube's
own download button to save; saved videos live in their own tab.

**X** — **hold two fingers anywhere**, the same gesture for the same reason. Hold a photo or video to save
it; drag the in-video button where you want it and pin it.

**TikTok** — the download button is in the feed, above the profile picture. **Hold two fingers anywhere**
for settings; *Advanced → Status report* copies every number behind every feature, which is the fastest way
to report something that is not working.

**Everywhere** — **Settings → Albrhi** is the one page listing every app Albrhi patches, with a switch
each. Turn one off and that tweak stops loading entirely, without uninstalling anything or losing its
settings. Reopen the app for the change to take effect.

**When something does not work:** open the tweak's diagnostics → read what actually attached → (on
Instagram) the magnifier scans the live view hierarchy → send the report. That loop replaced several rounds
of guessing.

---

## 🧠 How it is made

A few habits run through the whole repository, because each was paid for:

- **Measure before hooking.** What a class *is declared to have* is read from the app's own metadata
  (`objc-classes.py`), what a method's *signature is* is read from the runtime, and a hook is installed
  only where the running build agrees — a `%hook` on a method the class does not declare does not politely
  do nothing, it adds one.
- **Count the attempt, not only the result.** A diagnostic that reports the last event instead of a tally,
  or a counter on a path that never runs, sends you fixing what is not broken. Reports say what was
  *attempted*, what *succeeded*, and what *stood aside*.
- **A tweak may cost a feature; it may not cost the app.** Launch guards, reload budgets, and work on a
  layout path that is free the second time.
- **Nothing writes itself.** Reports are written when asked, every file that can grow has a ceiling and says
  so when it is hit.
- **Credit and licence are not optional.** GPLv3 sources are carried over with their authorship; unlicensed
  references are read for *architecture only*, and the line between a device tweak and a paid subscription
  is one this project does not cross.

The accumulated reasoning — what broke, why, and what was learned — lives in [CLAUDE.md](CLAUDE.md).

---

## 🗺️ Roadmap

**Done recently**
- [x] **YouTube direct download route** — survives app updates; own fragmented-MP4 remux, no FFmpeg; confirmed on a device
- [x] **A licence layer** — free week, keys, short codes, server renewal, revocation, an admin app
- [x] **Six tweaks in one package**, and Spotify, NextUp and Watch as their own, each with its own settings row
- [x] **Albrhi for YouTube Music** — lyrics, saving tracks, Downloads tab, no ads
- [x] **Instagram:** story-seen hiding fixed on 439, unsent messages kept **and marked**
- [x] **YouTube:** arrangeable tab bar, History tab, playback-error recovery, extra ad gates
- [x] **X:** fifteen features, a draggable in-video button, Face ID cover
- [x] **TikTok:** a card-based settings screen, save media from comments
- [x] **Tests that run on the build machine** for YouTube Music and YouTube

**Next**
- [ ] Confirm the deleted-messages log on a device — which message shape Instagram's update stream really carries decides whether text is captured
- [ ] Hiding the reels **seen** mark (`write_seen_state` still goes out)
- [ ] Take the host-test arrangement to the rest — the DASH ladder, the quality ranking and version comparison are pure functions
- [ ] Spotify publishing from its own workflow
- [ ] A backup of the licence store
- [ ] **Albrhi CarPlay, rebuilt from scratch in its own repository**
- [ ] Settings profiles · crash protection that disables a faulting feature rather than the whole tweak

---

## 🤝 Contributing

Issues and pull requests are welcome.

1. Fork and branch from `main`.
2. Keep one feature per file under the tweak's `src/Features/<Category>/`; in Instagram a settings page
   registers itself in `+load` under `src/Settings/Pages/`, and defaults go in that tweak's `src/Tweak.x`.
3. Add **both** Arabic and English strings to the tweak's `src/Localization/SCILocalize.m` — never hard-code
   user-facing text (`tools/check.py` enforces parity).
4. Follow the `SCI` prefix and Objective-C style; run `python3 tools/check.py` and build before opening the PR.
5. Bump the version in `control` **and** `SCIVersionString` together, add a changelog entry — **and bump
   `suite/control`**, or nothing ships.
6. By contributing you agree your work is licensed under the GPLv3.

---

## 🙏 Credits

- **[SoCuul](https://github.com/SoCuul)** — author of [SCInsta](https://github.com/SoCuul/SCInsta), the project Albrhi is derived from.
- **[RyukGram](https://github.com/faroukbmiled/RyukGram)** by faroukbmiled — a fellow SCInsta fork, read for where Instagram is hookable.
- **[YTKACE](https://github.com/itzzace/ytkace)** by itzzace (MIT) — the direct download method and several ad gates; **YTPlaybackFix** by Mark02 (MIT) — the playback-error recovery approach.
- **[iSponsorBlock](https://github.com/Galactic-Dev/iSponsorBlock)** by Galactic Dev (GPLv3) — the coloured progress-bar markers; **[SponsorBlock](https://sponsor.ajay.app)** by Ajay Ramachandran — the segment database (CC BY-NC-SA 4.0).
- **[YTMusicUltimate](https://github.com/dayanch96/YTMusicUltimate)** by **dayanch96** and **[YTMEnhanced](https://github.com/py233/YTMEnhanced)** by **py233** (GPLv3) — the YouTube Music hooks and synced-lyrics module. Their Premium claim deliberately is not carried over.
- **[EeveeSpotify](https://github.com/whoeevee/EeveeSpotify)** (GPLv3) — the Spotify ad blocking, without its Premium unlock.
- **[NextUp 3](https://github.com/Yves000/NextUp3)** by **Yves** (GPLv3) — Albrhi NextUp is a port of it; the design and nearly all of the implementation are his.
- **[watched](https://github.com/34306/watched)** by **34306** (MIT) — the Apple Watch pairing core.
- **[LightMessaging](https://github.com/rpetrich/libhooker)** by Ryan Petrich and **[libSandy](https://github.com/opa334/libSandy)** by opa334 — the messaging and sandbox profile NextUp needs.
- **[BHTikTok](https://github.com/BandarHL/BHTikTok)** by BandarHL and the fork by [al3raQe](https://github.com/al3raQe/BHTikTok), and **BHTwitter** — read for *where* an app is hookable, **never for code**; two compiled TikTok tweaks were read the same cautious way.
- **[JGProgressHUD](https://github.com/JonasGessner/JGProgressHUD)** by Jonas Gessner (MIT) · **[dav1d](https://code.videolan.org/videolan/dav1d)** by VideoLAN (the AV1 decoder) · **[FLEXing](https://github.com/SoCuul/FLEXing)** (runtime debugging).
- **Ibrahim Ismail AL-Rahn** — the Albrhi rebuild, bilingual layer, download and transcode engine, licence layer, and design.

---

## 📬 Connect

| | |
|---|---|
| Instagram | [@Ib.11p](https://instagram.com/Ib.11p) |
| Snapchat | [@Ib.1p](https://snapchat.com/add/Ib.1p) |
| Telegram | [@Ib11p](https://t.me/Ib11p) |

---

## ⚖️ License

Albrhi is a derivative work of SCInsta, distributed under the **GNU General Public License v3.0**
([LICENSE](LICENSE)). The source stays open, modifications are documented, and original authorship is
preserved as the licence requires. The Albrhi *licence* described above governs who may **run** the
released builds; it does not change the terms under which the source is published.

*Albrhi is not affiliated with, endorsed by or sponsored by Instagram, Meta Platforms, Inc., Google, YouTube, X Corp., TikTok or Spotify.*
