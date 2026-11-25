# Rocket's "Open in Rocket" Safari extension, read 2026-11-25, and what it would take for Instagram, YouTube and TikTok

**Source:** `RocketSafariExtension.appex` inside Rocket 4.27.2's Instagram 456.0.0 IPA (`api.getrocketapp.io/download/sideload/ccb11926`, the Rocket AltStore source).
Rocket is closed and paid: only the extension was read (it is a plain-text JavaScript file and a 66 KB stub binary), **nothing is copied**; the idea is a public one and is rewritten here.
Store, licence and entitlement code of Rocket was not examined.

## What it is

A **Safari Web Extension** (`NSExtensionPointIdentifier = com.apple.Safari.web-extension`, `MinimumOSVersion 15.0`), bundle id `<app bundle id>.RocketSafariExtension`, placed in the app's `PlugIns/`.

* `manifest.json` (v2): permission and content script for `*://instagram.com/*` and `*://*.instagram.com/*`, `run_at: document_idle`, top frame only. No background page, no native messaging.
* `content.js` (about 70 lines): on the page, decides where the same thing lives **inside the app** and sets `window.location.href = "instagram://…"`:
  * `/<username>` (not `about accounts direct explore reels reel p stories`) → `instagram://user?username=<name>`
  * `/explore/tags/<tag>` → `instagram://tag?name=<tag>`
  * `/p/<id>` and `/reel/<id>` → the page's own `<meta property="al:ios:url">` (Instagram publishes the native address there; absent while a client-side navigation is loading, so it waits for the page's progress bar `transitionend` and for `visibilitychange`)
  * it remembers the last hand-off so it never fires twice for the same page; refuses ports, credentials and non-instagram hosts.
* The native side is a stub: one class (`RocketSafariWebExtensionHandler`) whose only job is `completeRequestReturningItems:`. Info.plist carries two Rocket-only keys (`RocketSafariLinkHost`, `RocketSafariLinkMode = direct`) that nothing in the extension itself reads.

**Why it exists:** a re-signed (sideloaded) app has no Associated Domains, so iOS never hands it a tapped `https://instagram.com/...` link; Safari opens the website instead. The extension is the substitute: Safari loads the page, the script bounces into the app through its custom scheme. On a jailbreak (the real App Store app) universal links work and none of this is needed.

## For our three apps

| app | custom schemes in the Info.plist | what is measured | what is not |
|---|---|---|---|
| Instagram | `instagram://` | Rocket's script is the reference (user, tag, `al:ios:url`) | — |
| TikTok 47.8.0 | `snssdk1233` (also `snssdkonly1233`) | `MusicallyCore` contains the router strings `snssdk1233://aweme/detail/` (+ `aweme/detail/[0-9]+`), `user/profile/:uid`, `challenge/detail`, `music/detail`, `snssdk1233://search?keyword=` | the profile route takes a **numeric uid**, not `@name`: the page's `__UNIVERSAL_DATA_FOR_REHYDRATION__` JSON has it, not tried; `vm.`/`vt.tiktok.com` short links redirect to the long URL first |
| YouTube 21.47.6 | `youtube`, `vnd.youtube` (+ `-broad-matching`) | the schemes are in the Info.plist | the path forms (`youtube://www.youtube.com/watch?v=<id>`, `/shorts/<id>`, `youtu.be/<id>`) are the known community usage, **not read from the binary** |

## What building it needs

1. **One tiny appex per app** (Safari needs an executable and a principal class even for a script-only extension): a stub `SFSafariExtensionHandling`-style handler, built with `clang -target arm64-apple-ios15.0 -fapplication-extension -e _NSExtensionMain`, plus `manifest.json`, `content.js` (the only part that differs per app), icons and an Info.plist. No Substrate, no Theos tweak.
2. **IPA injection only** (`tools/inject-dylib.py`): copy the appex into `Payload/<App>.app/PlugIns/`, bundle id = `<host app id>.<name>`. A jailbreak package cannot add it: the App Store app lives in a container the package does not own, and on a jailbreak the extension is unnecessary anyway.
3. **The sideloader must re-sign the appex and rename its bundle id together with the app** (Sideloadly, AltStore, ESign do this for every `PlugIns/*.appex`). If it drops extensions, the feature silently does not exist: say so in the README.
4. **The person turns it on**: Settings › Safari › Extensions › enable, then allow on the site (once per site; iOS 16 asks "Always Allow" per website).
5. Gate and copy: it is a separate process with no access to the tweak's preferences, so it cannot honour the panel switch; "off" means disabling it in Safari. Say that on its row.

## Cost and risk

* A page load is needed before the hand-off (a blink of the website). Instagram and TikTok may change their page metadata or routes; the script then does nothing, it never breaks the website.
* Not tried on a device or in the simulator; nothing here has run.
