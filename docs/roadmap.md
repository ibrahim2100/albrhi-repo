[← Albrhi](../README.md)

# 🗺️ Roadmap

**Done recently**
- [x] **YouTube direct download route** — survives app updates; own fragmented-MP4 remux, no FFmpeg; confirmed on a device
- [x] **Licensing removed** — Albrhi is free; no key, no trial, no check
- [x] **Six tweaks in one package**, and Spotify, NextUp and Watch as their own, each with its own settings row
- [x] **Albrhi for YouTube Music** — lyrics, saving tracks, Downloads tab, no ads
- [x] **Instagram:** story-seen hiding fixed on 439, unsent messages kept **and marked**
- [x] **YouTube:** arrangeable tab bar, History tab, playback-error recovery, extra ad gates
- [x] **X:** fifteen features, a draggable in-video button, Face ID cover
- [x] **TikTok:** Albrhi as a native section of TikTok's own Settings, an update screen that shows once per release, save a comment's sticker, copy a comment without the name
- [x] **Instagram:** copy a caption by long-press, and a *Copy* button in the comment menu
- [x] **Tests that run on the build machine** for six tweaks — and CI runs them before it builds a release

**Next**
- [ ] Confirm the deleted-messages log on a device — which message shape Instagram's update stream really carries decides whether text is captured
- [ ] Hiding the reels **seen** mark (`write_seen_state` still goes out)
- [ ] Host tests for what still has none — the DASH remuxer (`SCIYTFragments`) and TikTok's link comparator
- [ ] Instagram 450 and newer: thirty-one hooked classes exist there only under Swift-mangled names (checked, not yet supported)
- [ ] Spotify publishing from its own workflow
- [ ] **Albrhi CarPlay, rebuilt from scratch in its own repository**
- [ ] Settings profiles · crash protection that disables a faulting feature rather than the whole tweak

---
