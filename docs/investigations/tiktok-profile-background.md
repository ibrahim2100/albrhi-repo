# TikTok profile background — what the binary says (47.1.0)

Written 2026-10-27 while adding the switch in TikTok 0.25.0. Everything here was read from `MusicallyCore` of
`com.zhiliaoapp.musically_47.1.0` with this repository's own tools; the reference tweak (`ProfileBanner` 1.0, by
Nasser | NoTimeToChill, no licence) only said where to look.

## The reference, read for architecture

A 86 KB dylib, filter `com.zhiliaoapp.musically`, four functions and no obfuscation:

| hook | target | what it does |
|---|---|---|
| answer | `+[TTKABTest profileBgInAllowList]` | returns 1 |
| wrapper | `-[TIKTOKProfileEditMainViewController p_resolveProfileBackgroundSnapshot]` | counts nesting in the thread dictionary around the original |
| getter | `-[TTKProfileComponentResponseModel profileBackground]` | when the original is nil and the counter is non-zero, builds a `TTKProfileBaseComponentModel` and calls `setBizData:` on it |

Nothing else: no UI, no network, no storage.

## What TikTok itself has (class dump, 109,552 classes)

- `TTKABTest` class methods `profileBgInAllowList q16@0:8`, `profileBgEnableConsumptionGroup q16@0:8`,
  `profileBgReduceTransparencyFixEnabled B16@0:8`, `profileBgEducationAnimationDuration d16@0:8`,
  `profileBgEducationToastDuration d16@0:8` (the same on `ABTestCodeGen`).
- `TIKTOKProfileEditMainViewController`: `p_resolveProfileBackgroundSnapshot`, `p_refreshProfileBackgroundDependentUI`,
  `p_setupProfileBackgroundCoverIfNeeded`, `p_didTapProfileBackgroundChangeButton`, `p_didTapProfileBackgroundCover`,
  `p_runProfileBackgroundFlowWithBgInfo:sourceView:`, `p_applyProfileBackgroundEditResult:`; ivars
  `_profileBackgroundInfo : TTKProfileBackgroundInfo` (Swift, `TikTokProfilePlatform`), `_hasProfileBackground`,
  `_hasProfileBackgroundComponent`, and the cover, backdrop and change button views.
- `TTKProfileComponentResponseModel`: `profileBackground : TTKProfileBaseComponentModel`, `hasProfileBackground`,
  `hasProfileBackgroundData`, `+profileBackgroundJSONTransformer`.
- `TTKProfileBaseComponentModel`: `bizData : NSDictionary`.
- Swift side (strings): `TTKProfileBackgroundService`, `…Coordinator`, `…CropViewController`, `…PreviewViewController`,
  `…VideoSelectionViewController`, `…EducationManager`, `…EditRequest`, `…EditResult`, `ProfileBgInfoStruct`,
  `ProfileBgVideoInfoStruct`, `ProfileBgAwemeInfoStruct`.

## Who reads the flags (caller scan)

`docs/investigations/na9-scripts/callers.py` over the binary with `objc_allimps.py`'s IMP table (about a minute each):

| selector | callers |
|---|---|
| `profileBgInAllowList` | `-[TTKProfileComponentDataController getRequestParamsWithParams:isCurrentUser:]` (+0x298) |
| `profileBgEnableConsumptionGroup` | the same method (+0x2e8) |
| `profileBgReduceTransparencyFixEnabled` | none |
| `hasProfileBackground`, `hasProfileBackgroundData` | `-[TTKProfileHeaderAdaptor p_setupComponentsWithModel:isCache:isPreload:]` (+0x50c, +0x548) |

**So the flags are parameters of the request for the profile components, not a local switch.** The server decides
whether to return a `profileBackground` component. This is why the feature is a cost (we tell TikTok something untrue)
and why the row says so.

## What `p_resolveProfileBackgroundSnapshot` does (read from the arm64, not decompiled)

It clears `_profileBackgroundInfo` and the two flags, reads the profile component response, and **sets
`_hasProfileBackgroundComponent = YES` when the response has a `profileBackground` component**; it then looks in that
component's `bizData` for a background-info entry, and only if there is one builds `_profileBackgroundInfo` and sets
`_hasProfileBackground = YES`. A first-time background is therefore the component present and no info in it.

## Open

- **Confirmed on the owner's phone, 2026-10-27 (0.25.0): the editor appears and works.** So `bizData = @{}` is accepted
  by the editor, and the allow-list flag plus the stand-in component is enough there.
- Not known: whether the server accepts a change from every account (one phone is one data point).
- Resolved later: the reference hands `setBizData:` an empty dictionary too (the constant at offset 0x1f0 is `__NSDictionary0__struct`,
  one of its imports), so `@{}` was not our guess alone. Checked 2026-10-27: it installs exactly three hooks, touches no
  consumption flag, and has no network, upload or storage code.
- `profileBgEnableConsumptionGroup` probably decides whether other people's backgrounds are *shown*; not touched.
