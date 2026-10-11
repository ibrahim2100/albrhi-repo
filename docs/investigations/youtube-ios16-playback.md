# YouTube 21.33.6 on iOS 16: "Something went wrong" — the investigation

**Conclusion, for CLAUDE.md §5.2:** on the one phone this was measured on, regular videos failed
because the system's video decoder was stuck (`-12913`, "decoder busy"); restarting the phone cured it.
Two diagnoses along the way were wrong and each shipped as a feature. This file keeps the evidence
and the order it arrived in, so the next person to see this screen does not repeat either.

Phone: iPhone 13 Pro (iPhone14,2), iOS 16.1, roothide jailbreak. App: official YouTube 21.33.6 IPA
installed outside the App Store (the last build iOS 16 runs). Reported 2026-10-09.

## The symptom

A regular video plays a second or two and stops with "Something went wrong". Shorts, and this
tweak's own downloads (the `VISIONOS` client), are fine. It happened **with the tweak removed**, signed
in or out, with no DNS or VPN — so nothing the tweak did could be the cause of the first failure.
Some videos play normally, usually the older and less watched ones.

## What the probes measured

Three layers of read-only probe (`SCIYTPoProbe`, 1.39.x–1.40.x):

- The player error chain is `playback 0` ← `MLPlayerError 2` ← `com.google.ios.hamplayer 2101` with
  details `sbdl_failed|…`. **`sbdl` is `AVSampleBufferDisplayLayer`** (the format string and
  `alwaysEnqueueDecodedSamplesToAvsbdl` are in the binary).
- The layer's own notification: `AVFoundationErrorDomain -11839` "Cannot Decode — the decoder
  required for this media is busy", under `NSOSStatusErrorDomain -12913`
  (`kVTVideoDecoderNotAvailableNowErr`), repeated about fifty times.
- The last compressed sample handed to the layer was **`vp09` (VP9)**. A video that played
  enqueued only `avc1`.
- Failing videos offer **three formats per resolution** (itags 134/243/396 = H.264/VP9/AV1); the
  video that played offers six, H.264 only.
- The app declares what it can play in `YTVSMediaCapabilities` (three entries, `codec#2 efficient`,
  `#4 10bit efficient`, `#8 10bit`; which number is which codec is inferred, not read). `#8` is software AV1,
  because `YTColdConfig iosPlayerClientSharedConfigPopulateSwAv1MediaCapabilities` is YES.

## Wrong diagnosis 1 — a missing proof-of-origin token (1.39.0–1.39.2)

Documented for other YouTube clients: without a PO token the server answers
`STREAM_PROTECTION_STATUS` → `ATTESTATION_REQUIRED` after a second or two. It fit the symptom. It was
tested rather than assumed, and was wrong for this phone: the iosguard challenge answered with no error,
11–13 tokens were minted (30 and 158 bytes), the media layer never heard a protection status,
and 36–41 chunks completed without error. Three releases of probe. CLAUDE.md said, at the time, that
the cause was found; it was not.

## Wrong diagnosis 2 — "this phone cannot decode VP9" (1.40.0–1.40.2)

The probes above point at VP9 and the display layer, and a forum claim said VP9 hardware decode is
unsupported on iPhone 13 / iOS 16.5. So 1.40.0 added a switch, "Compatibility: H.264 only", that
removed VP9/AV1 *video* from `YTIPlayerResponse -streamingData → adaptiveFormatsArray`.

**It did not work, and the owner's own hand showed why.** The video stuck at 0:00 and after a long wait
played sound with no picture. The report held **41,984** non-fatal `sabr.invalidformat` errors
(`init_metadata_badid_formatid_243/248/244/247` — VP9 itags the player no longer knew). In automatic
mode **the server picks the format itself** (`MLPlatypusABRLoader._serverDrivenSelectableFormats`) from
everything it has; the client's list does not restrict it. Choosing 1080p by hand worked because a manual
choice leaves the client exactly one format and the server serves that one.

1.40.1 then tried to give the loader's video format constraint (`-setVideoFormatConstraint:`) a runtime
subclass reducing it to the best H.264 format. **It never ran:** two reports said "attached … 0
constraint(s) wrapped". 1.40.2 added the device line and found that `VTIsHardwareDecodeSupported(vp09)`
answered **yes** on this phone — which the VP9 theory could not explain. A third mechanism, `auto_h264`,
turned the switch on by itself after the first failure and wrote it into the preferences for good.

## What settled it

After the owner restarted the phone (jailbreak off, then on again) and re-enabled the tweak:

- with "H.264 only" **on**, automatic mode was broken again (the filter, as above);
- with it **off**, automatic mode played **100%**, VP9 included.

So the failing state had been a stuck system decoder, cleared by the restart, and the filter had made
the symptom worse and made it permanent. 1.40.3 deleted the filter, the self-enabling switch, the
constraint hook and the AV1 declaration override, and replaced them with one alert per launch on
`-12913`: restart the phone.

## What is not known

- **Why it began** two days before the report, after a tweak update that touched nothing in playback —
  and the stock app without the tweak failed too. The jailbreak being on at the time is a candidate,
  not a finding.
- **Whether it comes back.** n=1 phone, one restart.
- Whether other iOS 16 phones show it. `AVF:11839;CM:12913` is reported by other people tied to a stuck
  hardware decoder (cleared by a reboot) — unverified here.

## If it comes back

1. Settings › General › the report: the device line (model, iOS, VideoToolbox answers) and the
   `frames handed to the display layer` line (which codec was enqueued).
2. Restart the phone and play the same video; say which of the two happened.
3. "Watch here" (`SCIYTWatch`) is offered when the app's error is shown: it fetches the video as a save
   does and plays it in the Centre.

## What this taught (also in CLAUDE.md §4)

- A switch that rewrites what the app is offered, to cure a fault whose cause is a guess about the
  device, is a second fault.
- A setting that turns itself on outlives the thing it answered.
- A measured fact and the story that explains it are two things: the display layer really did fail on
  `vp09`, and "so the phone cannot decode VP9" was an inference the same phone's own VideoToolbox
  contradicted.
