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
