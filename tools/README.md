# tools/

One line each; the long version, with the reason each exists, is CLAUDE.md §3.6.

| tool | for |
|---|---|
| `check.py`, `check-repo.py` | the source rules (28) and the repository-wide ones; run before every push |
| `run-host-tests.sh` | every host test (`shared/tests/host`, `tweaks/*/tests/host`) |
| `build.sh` (root), `build-local.sh`, `build-dylibs.sh`, `build-dav1d.sh` | packages, standalone dylibs, the AV1 decoder |
| `make-suite.sh`, `merge-control.py`, `make-repo.sh`, `fetch-published-debs.sh` | the `com.albrhi` package and the APT index |
| `make-depiction.py`, `release-notes.py`, `make-logo.py` | Sileo depiction, release notes from the changelog, the repo icon |
| `objc-classes.py`, `objc-diff.py`, `ref-leads.py`, `logos-new-encodings.py` | reading an app's real classes and selectors; what changed between builds |
| `inject-dylib.py`, `ipa-inject.html`, `sim-install.sh`, `sim/`, `sim-panel/`, `sim-player/` | putting a dylib in an IPA; running an app or a page in the iOS Simulator |
| `deb-edit.py`, `deb-edit.html`, `repo-index.html` | editing `.deb` metadata; the source's landing page |
| `doctor.sh`, `install-hooks.sh`, `hooks/` | readiness check and the git hook |
