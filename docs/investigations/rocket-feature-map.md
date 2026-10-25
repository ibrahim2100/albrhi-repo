# Rocket for Instagram 4.23.1 — what a closed reference teaches, and what the tools added

**Read for features and architecture only; nothing is copied** — the line CLAUDE.md §2 draws for every
unlicensed reference. Rocket is closed source with a paid store inside it (`ra-store-*` assets, an
entitlements dictionary). **Its licence, store and entitlement code was not examined**, as with Legizmo,
and nothing here unlocks, bypasses or imitates a paid feature. Its call *recording* is listed below and not
proposed: recording a voice call is a consent question in many places and a Terms question everywhere, and
that is the owner's decision, not a default.

Package: `me.alfhaily.rocket` 4.23.1, rootful `iphoneos-arm` (one `Rocket.dylib`, filter `com.burbn.instagram`,
11 MB), received 2026-10-11. Obfuscated: **282 of 287 class names are hashes** (`z005070a9b…`), the readable ones
are `RATabBarLayout*Cell`, `SAMKeychain`, `SDWebImageDownloader`; its UI strings are not in the clear; no
Logos symbols. Statically links SDWebImage and SAMKeychain; uses JavaScriptCore, Accelerate, VideoToolbox,
MetricKit, MapKit, sqlite3.

## The best source was not a tool

The vendor's own public Sileo depiction (`apt.getrocketapp.io/depiction/sileo/4EYOXC`) lists every feature and
three months of dated release notes. That is a feature map and a timeline of what Instagram changed
(compatibility notes for 435, 436, 439, 440 and 443) for free, and it came from reading what the author
published. **Try that before any disassembler.**

## Rocket's features against ours (Albrhi Instagram 4.5.0)

"Have" is judged from our settings rows, not from keywords. "Gap" means *no equivalent row today*.

| Rocket feature | Ours | Note |
|---|---|---|
| Hide ads / sponsored posts, Reels, Stories | have (hide ads) | |
| Browse Stories and DMs privately: seen, typing, screenshot, view-once replay | have | `disable story seen`, `typing`, `screenshot detection`, `unlimited replay` |
| Manual mark as seen | have | |
| **Mark as seen locally only; exclude chosen users from the blocker** (4.7) | **gap** | needs `setForceSeenIds:` / `hasSeenMediaId:forReelPK:` style state; selectors below |
| Retain deleted messages (4.19) | have, and **marked and logged** | ours is further on |
| Download feed, Reels, profile videos, Stories, DM media; higher-quality format choice | have | AV1 on device too |
| Downloads manager per account | have (Download centre) | |
| Disable video autoplay in Home feed | have | |
| Instants: unlimited replay, upload from Photos | partial | we disable creation; no upload |
| Date format, OLED theme, accent, app icon | have | |
| Follow-back status | have | |
| Export/import settings | have | |
| Auto-scroll Reels | have | |
| **Disable doomscrolling (stop infinite Reels)** (4.6) | **gap** | small; `sundialVideoPlaybackViewDidStartPlaying:` is a lead |
| **Stories do not auto-advance** (4.3) | **gap** | `_advanceToNextItemWithNavigationAction:` — **we already name `advanceToNextItemWithNavigationAction:`** |
| **Home feed List/Grid, rows and columns, Following/Favorites feeds, Following as default** (4.0–4.23) | **gap** | the biggest; `mainFeedNetworkSourceSessionDeps`, `feedSessionNeedsToRefresh:withReason:…` |
| **Save a post/Reel without the collection picker** (4.13, 4.23) | **gap** | `feedItemUFICellDidTapSaveButton:` |
| **Hide the buttons under feed posts** (4.8) | **gap** | |
| **Prevent accidental group creation when sharing** (4.8) | **gap** | |
| **Clickable links in captions and comments** (4.6) | **gap** | `coreTextView:didTapOnString:URL:`, `_findClosestIndexForURLOrTapActionForAttributedString:…` |
| **Disable link tracking** on copied/shared links (4.18) | **gap** | X's tweak already strips `s`/`t`; same idea |
| **Search the Story viewers list** (4.11) | **gap** | `viewerId` |
| **Watch profile** (auto-save new posts/stories/reels) and **Save all posts** incl. carousels (4.20) | **gap** | larger |
| **Settings profiles mapped to accounts** (4.12) | **gap** | |
| Themes, custom fonts, custom icons (4.16) | partial | we have accent, OLED, app icon |
| Clean cache; crash report export (4.14, 4.20) | **gap** | small |
| Reels in Picture in Picture (4.6) | **gap** | |
| Repost; copy caption, comment, media link, stickers from comments (4.3, 4.18) | **gap** | `reelsCopyCaption:`, `reelsCopyMediaURL:`, `reelsRepost:` are IG's own action selectors |
| Profile picture enlarge, profile stats | have (copy account info) | `profileAvatarActionsController:showExpandedProfilePicFrom:isLongPress:` |
| Hide friend suggestions from the Stories tray (4.18) | unclear | we hide the whole tray |
| **Discreet mode** — hide the tweak's own buttons when a screenshot is taken (4.14) | **gap**, and relevant | we draw download buttons |
| Safari "open in" extension for sideloaded builds (4.15) | gap | |
| **Record voice and video calls** | **not proposed** | see the top of this file |

Cheapest and most useful first, by the owner's priorities (privacy, quality, no regressions): doomscroll and
story auto-advance off; link-tracking strip; accidental-group guard; mark-seen-locally with exclusions; Story
viewer search; then Watch profile / Save all; Grid feed last.

## Leads (selectors Rocket names in the clear)

`python3 tools/ref-leads.py Rocket.dylib --tweak tweaks/instagram` subtracts Apple's SDK vocabulary and Rocket's
own selectors: **106 app-side selectors, 13 of them already in our sources** — an independent confirmation that
those are real Instagram internals (`fullscreenSectionController:didMarkItemAsSeen:`, `markLastMessageAsSeen`,
`initWithReelSeenDictionary:…forceSeenIds:`, `updateOutgoingStatusIsActive:threadKey:threadMetadata:typingStatusType:` …).
Instagram classes Rocket names as strings: `IGFeedItem`, `IGDirectRealtimeIrisDeltaApplicator`,
`IGDirectPublishedThread`, `IGDirectMessageMenuActionHandler`, `IGDirectThreadViewController`,
`IGLiquidGlassInteractiveTabBar` (Instagram's iOS 26 tab bar), `IGAuthHeaderStore` (**not touched**: an auth
header store is credentials territory).

**Every lead is unverified.** There is no Instagram binary on this machine (the 410/439/441 IPAs are not
here), so no selector above has been asked of the app. First step when one is available:
`tools/objc-diff.py --check <instagram> --tweak <new code>` and `objc-classes.py <instagram> --find-method <sel>`.

## What the tools added, measured

| Question | Our tools | REA 6.4.0 | Result |
|---|---|---|---|
| Classes in the dylib | `objc-classes.py --dump`: 287 | `inspect-native-dispatch-metadata`: 287 examined (574 with metaclasses), 2 s | **same answer** |
| Beyond that | type encodings, property types | protocols (51), categories (13), implementation addresses | each has what the other lacks |
| Decompile a method | none | Ghidra 12.1.4 through REA: correct on a test dylib; names are `Class::sel:` | **the only new capability**; not yet run on a real target |
| Large binary | any size, 17 s for YouTube's 33,263 classes | **refused**: 64 MiB metadata budget on YouTube 21.34.3 | ours |
| Obfuscated binary | readable names only | same | neither helped; strings and the vendor page did |
| Feature discovery on Rocket | `ref-leads.py` (new): 1,376 raw → 106 app-side | none | ours, built from this exercise |

REA's whole-binary analysis of YouTube (225 MB) was started for `didParseSelectableFormats:` and **cancelled by
the owner after 11 minutes without a result**; it is neither a success nor a failure of the tool. Decompiling a
single function from a big app needs a persistent session (the MCP server keeps one open) rather than one
`rea decompile` command per question.


---

# Rocket 4.24.0 (received 2026-10-25) — what changed, what the binary says, what REA did

**Same line as above: features and architecture only.** Licence, store, entitlement and the string-decryption
routine (Rocket's strings are not readable in the binary and `CCCrypt` is imported; which one decrypts what was not established) were **not** examined, and no decryption
was attempted: decrypting every string would expose the paid-store code this file deliberately leaves alone.

## The vendor's notes (public Sileo depiction, read 2026-10-25)

- **4.24.0** — hide friend suggestions in Reels; OLED theme fix (toggle switches turned black).
- 4.23.2 — profile watching faster ("significantly improved"); the "For You" menu label when Following is the default feed.
- 4.23.1 — bug fixes, iPad navigation. 4.23.0 — Following as the default Home feed, save feed posts without the collection picker, OLED Continue button.
- Compatibility notes still stop at Instagram 443 (4.13.1). Whether 4.24.0 runs on 450 is not stated anywhere.

## The two binaries, side by side

| | 4.23.1 | 4.24.0 |
|---|---|---|
| `Rocket.dylib` | 4,869,600 bytes | 4,903,104 bytes (+33 KB) |
| classes | 287 (282 hashed) | 289 (284 hashed) |
| app-side selectors named in the clear (`ref-leads.py`) | 604 | 605; **one new**, `_ra_scrollFadeView` (Rocket's own) |
| of which already named in `tweaks/instagram` | 54 | 54 |

**Everything is renamed on every build**: the class names *and* the selectors of Rocket's own classes are hashes that
change between releases (`z0453dff…` in one, a different string in the next), so a class-by-class diff of two Rocket
builds is meaningless — only 5 class names are readable at all (`RATabBarLayoutBarCell/EmptyCell/HiddenCell`, `SAMKeychain`,
`SDWebImageDownloader`). A diff that matches on a *name-independent* signature (superclass, counts, ivar types, the
few clear selectors) still pairs only part of them (54 new vs 52 gone), because Rocket also changes ivar names and
counts. **The new feature leaves no new app-side selector**, so it is built from selectors it already used, and its
class and string names are encrypted: it cannot be read from this binary without the decryption step above.

## How Rocket works, from what is in the clear

- **Hooks are installed at runtime through the Objective-C runtime**, not through Substrate: it imports
  `class_replaceMethod`, `method_setImplementation`, `method_exchangeImplementations` and `imp_implementationWithBlock`
  (plus `objc_allocateClassPair`, `class_addMethod`, `class_addProtocol`, `objc_allocateProtocol` for classes it builds
  itself), and **no `MSHookMessageEx`**. Block implementations (`imp_implementationWithBlock`) mean most replacements are
  closures, not functions with names. (NA9, by contrast, uses `MSHookMessageEx` with trampolines; see `na9-analysis.md`.)
- **Linked frameworks say what it does:** `AVFoundation`/`AVKit`/`VideoToolbox`/`CoreMedia`/`CoreVideo` (downloads, quality,
  Reels in PiP), `Photos`, `ImageIO`, `CoreImage`, `Accelerate`; `JavaScriptCore` (a scripting layer or remote rules —
  not read); `sqlite3` (a local store: downloads, watched profiles); `MetricKit` (probably the crash-report export the notes mention);
  `UserNotifications` (watch profile notices); `MapKit`, `WebKit`, `QuickLook`, `CFNetwork`, `Security` (keychain via
  the bundled `SAMKeychain`), `CoreText` (themes and custom fonts).
- **Bundled resources:** eight app icons (Ember, Evergreen, Midnight, Ocean, Orchid, Rose, Sand, Slate, each in several sizes),
  theme previews in light and dark for each, four home-feed layout icons (`layout-icon-grid/list/multi/video`), a
  release-highlights image, a `NYTPhotoViewer` bundle (the profile-picture viewer), `cercube-icon.png`, and `ra-store-*`
  images (the paid store; not examined).
- **A custom tab-bar layout** is the only feature whose classes are readable (`RATabBarLayout*Cell`).

## Where REA stood

REA 6.4.0 with Ghidra 12.1.4 opened the file (arm64, sha256 `ccac562e…`) and then **timed out on every query after the
first (330 s each, three tries: overview, class list, session status)**; no analysis process was observed running. The
4.4 MB `__text` of an obfuscated dylib did not finish in the budget the server allows, where NA9's 1.6 MB did. Nothing
here was decompiled. What did the work: `objc-classes.py --dump`, `ref-leads.py`, `otool`, and — the important
part — **an Instagram binary on this machine** (below).

## Verified against Instagram 450.1.0 (the step this file said was missing)

`com.burbn.instagram_450.1.0_und3fined.ipa` is in Downloads. Of Rocket 4.24.0's 541 usable leads (property noise and
underscore ivars removed), **329 are declared by some class in 450.1.0** (main binary plus `FBSharedFramework`) and 212
are not (Rocket's own helpers such as `rocketSettingsAccent`, UIKit/SDK selectors and a few Instagram selectors that
are gone). So the lead list is mostly real, and `docs/investigations/instagram-450-check.md` is the other half of the
same exercise: **the Instagram tweak's own hooks against 450.1.0** — 31 of the classes it hooks now exist only under
Swift-mangled names.

## "Hide friend suggestions in Reels" (new in 4.24.0) — the 450.1.0 classes behind it

Nothing in Rocket's clear text names it, but 450.1.0 has a family built for exactly this carousel:

- `IGSundialSuggestedUsersSectionController` (`IGListSectionController`; ivars `_suggestUserModel : IGSuggestedUserInReelsModel`,
  `_netegoItem : IGSundialNetegoItem`, `_quadCardProvider`; `-numberOfItems q16@0:8`, `-cellForItemAtIndex:`, `-isAd B16@0:8`)
  and the follow/dismiss callbacks `quadCardContainerProvider:didTapFollowButtonForUser:index:`, `…didTapDismissButtonForUser:index:isLastCard:`.
- `_TtC29IGSundialNetegoSuggestedUsers43IGSundialFriendingCarouselSectionController` (Swift; `-numberOfItems q16@0:8`,
  `-sizeForItemAtIndex:`, `-didUpdateToObject:`), with `IGSundialFriendingCardProvider`, `IGSundialFriendingCarouselCell`,
  `…PageCell`, `…ContainerView`, and the logger `IGSundialNetegoSuggestedUsersLogger`.
- The old name `IGSuggestionsUnitViewModel` / `IGSuggestedUnitViewModel` the Instagram tweak hooks for "no suggested users"
  survives only as a Swift-mangled class (`_TtC17IGSuggestionsUnit26IGSuggestionsUnitViewModel`) and the other not at all.

**A candidate gate, not a finding:** an IGListKit section whose `-numberOfItems` answers 0 draws nothing, which is how the
tweak's other list filters work. Whether either controller's `-numberOfItems` is the right door, and whether returning 0
there is safe while the list adapter holds the object, is unknown and needs a device. **Not built.**

## What Rocket 4.24.0 adds to the gap list above

Only one row: **hide friend suggestions in Reels** (gap; leads above). The OLED toggle fix and the profile-watching
speed-up change nothing we lack, and the Following-default and save-without-picker features of 4.23.0 were already rows.
