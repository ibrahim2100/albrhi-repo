# Release checklist

### Does this even need a version?

Bump only if the change touches a tweak's `src/`, `control`, `Makefile`, `layout/`, `shared/tweak.mk` or `build.sh`.
Changes to `tools/`, a workflow or the docs alter nothing users install: a bump there costs a full rebuild and
shows everyone an update that contains no change. Those go in the commit message and nowhere else.

### The four numbers (CLAUDE.md §3.3)

- [ ] `tweaks/<app>/control` — `Version:`
- [ ] `tweaks/<app>/src/…` — `SCIVersionString` (`"v…"`, same number)
- [ ] `tweaks/<app>/CHANGELOG.md` — a new newest entry with that number (release notes and the Sileo page are generated from it)
- [ ] `suite/control` — a new `Version:`, **and** a `suite/CHANGELOG.md` entry. The suite is rebuilt from every tweak and its
      version is its own: `v<suite>` already tagged means "already released — building, not releasing", a green run and no update.

### Then the pages that repeat them

- [ ] `README.md` — the badges at the top and the table row (`check-repo.py` compares them with `control`)
- [ ] `CLAUDE.md` — *Known state* (§7), and the paragraph of the app's section (§5) if something learned there changed

### Before pushing

- [ ] `python3 tools/check.py` and `python3 tools/check-repo.py`
- [ ] `bash tools/run-host-tests.sh`
- [ ] `./build.sh <tweak> rootless` (and a roothide build if the change is about packaging)
- [ ] no `+N` in any version, and **no change under `tools/` or `shared/` in the same commit** (a shared concurrency group drops a pending run)

### After pushing

- [ ] CI: host tests, then build and release. A red host test withholds the release on purpose.
- [ ] The run ends by asking the live URL for the new version; if it says no, the release is not done.
- [ ] Refresh the source in Sileo/Zebra. On a device: what the Diagnostics page says, not what the code was meant to do.
