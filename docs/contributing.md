[← Albrhi](../README.md)

# 🤝 Contributing

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
