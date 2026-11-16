[← Albrhi](../README.md)

# 🧠 How it is made

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

The accumulated reasoning — what broke, why, and what was learned — lives in [CLAUDE.md](../CLAUDE.md).

---

---

# 🧭 What is in here

**Albrhi** is a personal workshop for iOS tweaks that is also a working APT source: it builds itself,
publishes its own releases, and serves a Sileo/Zebra repository from GitHub Pages. It is written for
learning as much as for using — the code is commented to explain *why*, and the reasoning behind the
awkward parts is kept in [CLAUDE.md](../CLAUDE.md) rather than lost.

Developed by **Ibrahim Ismail AL-Rahn** ([@ibrahim2100](https://github.com/ibrahim2100)).

**Nine tweaks. Six ship inside `com.albrhi`; three stand on their own.**

| Tweak | Patches | Version | In `com.albrhi` | What it does |
|---|---|---|:-:|---|
| **[Instagram](tweaks/instagram.md)** | Instagram | 4.8.2 | ✅ | downloads, AV1 reels transcoded on the device, a quieter feed, watching stories without a receipt, unsent messages kept and marked |
| **[YouTube](tweaks/youtube.md)** | YouTube | 1.50.0 | ✅ | downloads that survive app updates, their own Download Centre tab, no ads, SponsorBlock, background playback |
| **[X](tweaks/x.md)** | X / Twitter | 0.23.0 | ✅ | media downloads with a button you can place yourself, and fifteen-plus switches for what X does |
| **[TikTok](tweaks/tiktok.md)** | TikTok | 0.30.0 | ✅ | a download button in the feed, photo posts, no ads, confirmations, privacy |
| **[YouTube Music](tweaks/youtube-music.md)** | YouTube Music | 0.10.1 | ✅ | synced lyrics, saving tracks, no ads, background playback |
| **[Panel](tweaks/panel.md)** | Settings | 0.11.0 | ✅ | the Albrhi page: a switch per app, a guide, backup |
| **[Spotify](tweaks/spotify.md)** | Spotify | 0.2.5 | — | no ads, no Premium popups, sponsored podcast segments skipped |
| **[NextUp](tweaks/nextup.md)** | SpringBoard + five media apps | 0.3.1 | — | what plays next, on the Lock Screen — a GPLv3 port |
| **[Watch](tweaks/watch.md)** | SpringBoard, Watch app | 0.6.1 | — | pair a newer watchOS than iOS expects, and hold watchOS 26 back — an MIT port |

Each is a self-contained Theos project under `tweaks/` with its own sources, package identity and
version, and **they never meet at runtime**: an injection filter binds each dylib to one bundle id, so
the YouTube tweak is never loaded into Instagram. What they share is the build plumbing — the checks,
the build script and the APT index.

`com.albrhi` is built by `tools/make-suite.sh`, which picks up every `tweaks/*/control` automatically.
A tweak stays out of it only by carrying a `.no-suite` marker — Spotify, NextUp and Watch do.

> Albrhi is written by **Ibrahim Ismail AL-Rahn**. One tweak, the Instagram one, began from
> [SCInsta](https://github.com/SoCuul/SCInsta) by **SoCuul** (GPLv3) and is credited as such in-app, in the
> package metadata and in the source headers; the rest of the project is not derived from it. Every
> piece of code carried over from another open-source project is listed in [NOTICE.md](../NOTICE.md).

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

