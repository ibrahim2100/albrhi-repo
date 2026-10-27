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

- `device/` — `albrhi-mirrord`, a root process that **starts by itself** (a LaunchDaemon installed by the package, also after
  every restart) and sits idle. It listens on **127.0.0.1 only**. When an authenticated Mac connects it captures the display
  with `CARenderServerRenderDisplay`, sends JPEG frames and a **report**: iOS version, lock state, which private symbols were
  found, how long a capture took, whether the picture changed since the last frame, how much of it is black.
- `mac/Viewer.m` — starts the USB tunnel (`iproxy`) itself, pairs once, shows the frames and the report.
- **Nothing else**: no touch injection, no power or brightness change, no network exposure.

### Why there is a pairing

**Loopback is not private on a phone: any app on the device can connect to 127.0.0.1.** So nothing is sent to a client that has
not proved it holds a secret only a paired Mac has. (An earlier version of this stage said "loopback only" as though that settled
it, then used a token printed in a terminal; the token could not survive taking the terminal away, so it became a pairing.)

- **Once:** the viewer asks to pair, the phone shows a six-digit code in an alert (it appears over the lock screen too), you type
  it on the Mac, and the daemon hands over a random 32-byte secret. It is kept `0600` on the phone
  (`/var/mobile/Library/Preferences/com.albrhi.mirror.pairing`) and on the Mac
  (`~/Library/Application Support/AlbrhiMirror/pairing`). Three wrong codes or 120 seconds end the attempt; no new alert more than
  once every 20 seconds or within 30 seconds of a failed attempt.
- **Every session:** each side sends a random nonce and proves it knows the secret with HMAC-SHA256 over both nonces and its role,
  so the Mac also knows it is talking to the daemon and not to an app squatting on the port. A client that cannot prove it gets a
  closed connection and nothing else; a client that says nothing is dropped after 5 seconds.
- **Not yet:** the frames are not encrypted. They never leave the USB tunnel; encryption comes before any listener on a network
  (stage 4).

## Build

```bash
bash experiments/mirror/device/build.sh roothide   # → ~/Desktop/Albrhi-Mirror/*_roothide.deb  (your phone)
bash experiments/mirror/device/build.sh rootless   # → ~/Desktop/Albrhi-Mirror/*_rootless.deb
bash experiments/mirror/mac/build.sh               # → ~/Desktop/Albrhi-Mirror/viewer   (+ /tmp/albrhi-mirror-test/mirrord-host, a TEST build)
```

The build proves the flavour from the staged paths (no `var/jb` in a roothide package), like `tools/build-local.sh`.
The Mac needs `iproxy` (`brew install libusbmuxd`).

**Tested on the Mac only**, against the daemon's host build (`mirrord-host`, which sends a moving test picture and is **not** the
phone's daemon): the wire format; pairing with wrong codes (nothing stored) and the right code (the same secret on both sides, both
files `0600`); an authenticated session; a Mac with a wrong secret; an impostor daemon that cannot prove the secret; a client that
sends a bad proof or none (nothing sent back, dropped after 5 s); `--unpair`; the install script's output with a stand-in
`jbroot`/`launchctl` (the plist is valid and names the resolved binary). **Not tested on a phone**, and therefore not tested:
whether the capture works, whether the alert appears, whether `launchctl load` accepts the plist on this jailbreak, and
whether the service survives a restart or the phone locking.

If the viewer shows a coloured moving pattern and `iOS (host test build, no iPhone)`, it is talking to the Mac test build and not
the phone: `pkill mirrord-host`.

## Trying it on the phone

1. Install `com.albrhi.mirror.probe_0.2.0_iphoneos-arm64e_roothide.deb`. The service starts by itself. **Do not start the daemon by
   hand any more** (two copies fight for the port). To check it: `launchctl list | grep mirrord`, and `cat /tmp/albrhi-mirrord.log`.
2. Plug the phone in by USB, unlocked and trusted.
3. On the Mac open `~/Desktop/Albrhi-Mirror/viewer`. **First time:** an alert with a six-digit code appears on the phone; type the
   code in the window on the Mac. After that, opening the viewer is enough.

### What to try, and what to send back

Take a screenshot of the viewer window (it shows the numbers) in each state:

| | what to do | what it tells us |
|---|---|---|
| **A** | phone unlocked, screen on; swipe around | does capture work at all; does the picture change (`CHANGED`); capture time |
| **B** | press the side button (screen off, locked) and wait 5 s | does it keep rendering; `LOCK STATE`; does the picture freeze, go black, or show the lock screen; **did the daemon survive** |
| **C** | raise or tap the screen to show the lock screen, without unlocking | what is captured on the lock screen |

Also send any line that starts with `CAPTURE ERROR`, and `cat /tmp/albrhi-mirrord.log` if something did not start (it has the line
`pairing alert closed: result …`, never the code). To undo everything: remove the package (it stops the service and forgets the
pairing); on the Mac `viewer --forget`.

## What comes next, only if A and B come back usable

2. H.264 instead of JPEG (VideoToolbox). 3. Touch injection (BackBoardServices / IOHID). 4. Encryption, then and only then a LAN
listener. 5. Keeping the phone usable while "locked": whether that is a dark but awake screen, a cover, or something else depends
entirely on what B shows — it is not decided here.
