[← Albrhi](../README.md)

# 📲 Sideloading

Instagram, YouTube, X and TikTok are also built as **standalone dylibs** (`Albrhi*.dylib`) attached to each
release, for injecting into a decrypted IPA with LiveContainer, Sideloadly or cyan — or with
`tools/ipa-inject.html` in a browser. A sideloaded build has no Settings panel, so
it is simply on: it asks nothing and needs nothing entered. A dylib and the suite can never be injected
twice: the suite declares `Conflicts`/`Replaces` on them.

---
