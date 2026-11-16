# Who made what

**Albrhi is written by Ibrahim Ismail AL-Rahn.** Copyright © Ibrahim Ismail AL-Rahn. It is distributed under the
[GNU General Public License v3.0](LICENSE) and is free to run.

Most of the code in this repository was written for Albrhi, over many months: the bilingual layer, the Download
Centres and the download and transcode engines, the settings panel, the diagnostics, the update and source
tooling, and the design. A few tweaks began from, or carry code from, other open-source projects. **Those are named
here, tweak by tweak, so that credit goes where it is owed and Albrhi's own work is not mistaken for anyone else's
(or the other way round).** Each carried-over file also keeps its upstream notice in its source header.

## Tweak by tweak

| Tweak | What it is | Carried over from other projects |
|---|---|---|
| **Albrhi** (`com.albrhi`) | The package most people install: the five app tweaks and the panel, switched per app | Nothing of its own; it contains the tweaks below |
| **Instagram** | Began from **SCInsta** by SoCuul (GPLv3) and has grown far beyond it. The download engine and Download Center, the AV1 converter, the deleted-messages log, copy by long press, diagnostics and the Arabic and English layer were written for Albrhi | The starting point: SCInsta by [SoCuul](https://github.com/SoCuul/SCInsta) (GPLv3). Its notice stays in the files that came from it |
| **YouTube** | Albrhi's own: the direct download route, the Download Centre and its player, the ad blocking, the playback-error recovery | The direct download method and several ad gates from **YTKACE** by itzzace (MIT); the playback-error recovery approach from **YTPlaybackFix** by Mark02 (MIT); the coloured progress-bar markers derive from **iSponsorBlock** by Galactic Dev (GPLv3); segment data from **SponsorBlock** by Ajay Ramachandran (CC BY-NC-SA 4.0) |
| **X** | Albrhi's own: the download pipeline, the switch recorder and its settings, the draggable save button | The timeline section filter, the typing-indicator and screenshot-detection switches, the number displays and a set of interface switches from **NeoFreeBird** by orionblur (GPLv3). Where to hook was learned from BHTwitter and TWIGalaxy; no code was taken from either |
| **TikTok** | Albrhi's own, written from the app's own binaries | Nothing carried over. BHTikTok (BandarHL, al3raQe), NA9, VibeTok, OSTikTok and ProfileBanner were *read* to learn where TikTok can be hooked; **no code was taken from any of them** |
| **YouTube Music** | Albrhi's own: saving tracks, the Downloads tab, the lyrics sources and matching, translation | The hooks and the synced-lyrics module from **YTMusicUltimate** by dayanch96 and **YTMEnhanced** by py233 (GPLv3). Their Premium claim is deliberately not carried over |
| **Panel** | Albrhi's own: Settings › Albrhi, the guide, backup | Nothing |
| **WhatsApp** (separate package, source private) | Albrhi's own | Nothing |
| **NextUp** (separate package) | **A port** of NextUp 3 by [Yves](https://github.com/Yves000/NextUp3) (GPLv3). The design, the private-API research and nearly all of the implementation are his; this port rebuilt the settings pane and rebranded the package | NextUp 3, as described; LightMessaging by Ryan Petrich and libSandy by opa334 |
| **Watch** (separate package) | The pairing core is **watched** by 34306 (MIT, licence shipped in the package); Albrhi adds the master switch, the settings page, the diagnostics and the bilingual interface | watched by [34306](https://github.com/34306/watched) |
| **Spotify** (not published) | Albrhi's own shell | The ad blocking from **EeveeSpotify** (GPLv3), without its Premium unlock |

## Libraries

JGProgressHUD by Jonas Gessner (MIT) · dav1d by VideoLAN (the AV1 decoder) · FLEXing (runtime debugging).

## What was only read

Reference tweaks with no licence, or a licence that forbids it, are read for *where an app can be hooked* and
nothing is copied from them. The rules, and the reasoning behind each, are in [CLAUDE.md](CLAUDE.md), section 2.

## If something here is wrong

If you wrote code that is carried over and it is not credited, or credited wrongly, open an issue or write to the
developer and it will be fixed.
