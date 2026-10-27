# Albrhi Mirror — an experiment, stage 1

**Not published, not in the suite, no workflow.** The question it answers: *can this phone's screen be captured and,
later, controlled from a Mac while the phone is locked — the way Apple's iPhone Mirroring does it — on iOS 16.1 where
Apple's own feature does not exist?*

## Why our own, and not Apple's

Apple's iPhone Mirroring app on the Mac (`com.apple.ScreenContinuity`) talks to a program **on the iPhone**
(`ScreenContinuityServices`, `ScreenContinuityShell.app`). The iOS 26.5 and 27.0 images carry it; the iOS 16.1 image
(1,435 private frameworks) has nothing of it. Faking a version check would leave the Mac talking to nothing.
So the other end has to be written here: a program on the phone and a viewer on the Mac, with our own protocol.

## What stage 1 is (and is not)

- `device/` — `albrhi-mirrord`, a root process that listens on **127.0.0.1 only**, captures the display with
  `CARenderServerRenderDisplay`, sends JPEG frames and a **report** (iOS version, lock state, which private symbols were
  found, how long a capture took, whether the picture changed since the last frame, how much of it is black).
- `mac/Viewer.m` — shows the frames and the report.
- **Nothing else**: no touch injection, no power or brightness change, no persistence, no network exposure. The Mac reaches
  the phone through `iproxy` over USB.
- **Loopback is not private on a phone: any app on the device can connect to 127.0.0.1.** So each run prints a random
  **TOKEN**; the first message must carry it, and a connection that does not is closed without a reply. The daemon also
  stops by itself after 15 minutes (`--lifetime`). This was added after the first version, which said "loopback only" as
  though that settled it. Pairing and encryption for a network listener are stage 4, and nothing leaves the loopback before them.

The report exists because the hard part is the one thing a Mac cannot answer: **what iOS 16.1 does with the display when
the phone is locked.** Whether it keeps rendering, goes black, or sends the last frame decides the whole design.

## Build

```bash
bash experiments/mirror/device/build.sh roothide   # → ~/Desktop/Albrhi-Mirror/*_roothide.deb  (your phone)
bash experiments/mirror/device/build.sh rootless   # → ~/Desktop/Albrhi-Mirror/*_rootless.deb
bash experiments/mirror/mac/build.sh               # → ~/Desktop/Albrhi-Mirror/viewer   (+ /tmp/albrhi-mirror-test/mirrord-host, a TEST build)
```

The build proves the flavour from the staged paths (no `var/jb` in a roothide package), like `tools/build-local.sh`.
**Tested on the Mac only:** the wire format, the token (right, wrong and none) and the lifetime limit, with the host build of the
daemon, which sends a moving test picture and is **not** the phone's daemon: 6 distinct frames, JPEG valid, listener bound to
loopback, a wrong or missing token gets nothing. **Not tested on a phone.** If the viewer shows a coloured moving pattern and
`iOS (host test build, no iPhone)`, it is talking to the Mac test build and not the phone: `pkill mirrord-host`.

## Trying it on the phone

1. Install `com.albrhi.mirror.probe_0.1.1_iphoneos-arm64e_roothide.deb`.
2. On the Mac, with the phone connected by USB and trusted: `iproxy 9777 9777` and leave it running.
3. On the phone, **as root**, start it by hand (it does not start by itself) and **read the `TOKEN` line it prints**:
   `sudo albrhi-mirrord` (NewTerm), or over ssh (`iproxy 2222 22`, then `ssh root@127.0.0.1 -p 2222`, `nohup albrhi-mirrord &`).
   If `albrhi-mirrord` is not on the PATH, `$(jbroot /usr/bin/albrhi-mirrord)`. Nothing on the Mac side works without this step:
   with no daemon on the phone the viewer only says it cannot connect.
4. On the Mac: `~/Desktop/Albrhi-Mirror/viewer` (it asks for the token; or `viewer --token <TOKEN>`).

### What to try, and what to send back

Take a screenshot of the viewer window (it shows the numbers) in each state:

| | what to do | what it tells us |
|---|---|---|
| **A** | phone unlocked, screen on; swipe around | does capture work at all; does the picture change (`CHANGED`); capture time |
| **B** | press the side button (screen off, locked) and wait 5 s | does it keep rendering; `LOCK STATE`; does the picture freeze, go black, or show the lock screen; **did the daemon survive** (a dead daemon is itself the finding) |
| **C** | raise or tap the screen to show the lock screen, without unlocking | what is captured on the lock screen |

Also send any line that starts with `CAPTURE ERROR`, and say how the daemon was started.

## What comes next, only if A and B come back usable

2. H.264 instead of JPEG (VideoToolbox). 3. Touch injection (BackBoardServices / IOHID). 4. Pairing code and encryption,
then and only then a LAN listener. 5. Keeping the phone usable while "locked": whether that is a dark but awake screen,
a cover, or something else depends entirely on what B shows — it is not decided here.
