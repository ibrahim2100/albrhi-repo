# docs/

Not the user guide (that is the root `README.md`) and not the rules (that is `CLAUDE.md`). This folder is the **evidence**: what was
measured, in what order, and what turned out wrong.

| file | what it is |
|---|---|
| `audit-2026-10.md` | the whole-repository audit and what it left open |
| `investigations/` | one file per thing that was taken apart |
| `investigations/vibetok.md`, `ostiktok.md`, `asjtok-asjtube.md`, `na9-analysis.md` | TikTok references: what each hooks, nothing copied |
| `investigations/ytlite.md`, `youtube-ios16-playback.md` | YouTube: a closed reference, and the playback fault that was a stuck decoder |
| `investigations/rocket-feature-map.md`, `instagram-450-check.md` | Instagram: a closed reference, and the check of the 450 build |
| `investigations/tiktok-profile-background.md` | who reads the profile-background flags |

A reference is read for its public feature list and for the selectors it names; its licence is checked **before** it is opened (CLAUDE.md §2).
