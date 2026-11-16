[← Albrhi](../README.md)

# ⚠️ Instagram and roothide Bootstrap

**On [roothide Bootstrap](https://github.com/roothide/Bootstrap), Instagram 442 and newer crashes when you
change your profile picture. It is not caused by Albrhi, and no version of Albrhi can fix it.**

That reads like every tweak author blaming the loader, so here is how it was established. The fault was cut
in half, then in half again: every feature removed — **crash**; every hook installed with every setting
answering false — **crash**; a dylib of **one file that logs a line, no hooks, no classes, no load-time
work** — **crash**; the same tweak merged by hand into the app with no jailbreak injecting it — **no crash**.
An empty 128 KB library is enough, and the identical code injected differently does not crash at all.

**What you can do:** turn Albrhi off for Instagram while changing a picture, or use a manually merged build.

---
