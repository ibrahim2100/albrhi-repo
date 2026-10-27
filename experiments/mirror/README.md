# Albrhi Mirror — an experiment, stage 1

**Not published, not in the suite, no workflow.** The question it answers: *can this phone's screen be captured and,
later, controlled from a Mac while the phone is locked — the way Apple's iPhone Mirroring does it — on iOS 16.1 where
Apple's own feature does not exist?*

## Why our own, and not Apple's

Apple's iPhone Mirroring app on the Mac (`com.apple.ScreenContinuity`) talks to a program **on the iPhone**
(`ScreenContinuityServices`, `ScreenContinuityShell.app`). The iOS 26.5 and 27.0 images carry it; the iOS 16.1 image
(1,435 private frameworks) has nothing of it. Faking a version check would leave the Mac talking to nothing.
So the other end has to be written here: a program on the phone and a viewer on the Mac, with our own protocol.

## The three pieces

| | |
|---|---|
| **`device/app`** — *Albrhi Mirror*, an app on the phone | the switch (**off until you turn it on**), the **Pair a Mac** button, and the **six-digit code** with a countdown. English and Arabic (right to left). |
| **`device/daemon`** — `albrhi-mirrord`, a root service | starts by itself (LaunchDaemon) and sits idle. Listens on **127.0.0.1 only**. When an authenticated Mac connects it captures the display with `CARenderServerRenderDisplay` and sends JPEG frames plus a **report**: iOS version, lock state, which private symbols were found, capture time, whether the picture changed, how much of it is black. |
| **`mac/Viewer.m`** — the viewer on the Mac | starts the USB tunnel (`iproxy`) itself, pairs once, shows the frames and the report. |

Nothing else: no touch injection, no power or brightness change, no network exposure.

## Why the app, and why a pairing

**Loopback is not private on a phone: any app on the device can connect to 127.0.0.1.** So nothing is sent to a client that
has not proved it holds a secret only a paired Mac has. Earlier versions of this stage got there in two wrong ways first: "loopback
only" as though that settled it, then a token printed in a terminal (which does not survive taking the terminal away), then an alert
the daemon could not show. The app is the answer to all three, and it makes the start of a pairing something only the person holding
the phone can do.

- **Off by default.** A fresh install serves nothing and answers every connection with one word, `disabled`.
- **Pairing starts on the phone.** *Pair a Mac* asks the daemon to open a pairing window (120 seconds, three tries) and shows the
  code the daemon made. A Mac that merely asks, without a window, is refused (`pairing-closed`), and so is any other app. The code
  works once.
- **What pairing leaves behind:** a random 32-byte secret, `0600` on the phone (`/var/mobile/Library/AlbrhiMirror/pairing`, root)
  and on the Mac (`~/Library/Application Support/AlbrhiMirror/pairing`).
- **Every session:** each side sends a random nonce and proves it knows the secret with HMAC-SHA256 over both nonces and its role,
  so the Mac also knows it is talking to the daemon and not to an app squatting on the port. A client that cannot prove it gets a
  closed connection and nothing else; one that says nothing is dropped after 5 seconds.
- **Switching off, or forgetting the pairing, ends a running session.**
- **The app and the daemon** talk over a Unix socket (`/var/mobile/Library/AlbrhiMirror/control.sock`, owned by mobile, mode `0600`);
  the daemon also checks the peer's uid. An ordinary sandboxed app cannot reach that path. The app itself carries the entitlements
  a jailbreak app uses (`platform-application`, no sandbox).
- **Not yet:** the frames are not encrypted. They never leave the USB tunnel; encryption comes before any listener on a network (stage 4).

## Build

```bash
bash experiments/mirror/device/build.sh roothide   # → ~/Desktop/Albrhi-Mirror/*_roothide.deb  (your phone)
bash experiments/mirror/device/build.sh rootless   # → ~/Desktop/Albrhi-Mirror/*_rootless.deb
bash experiments/mirror/mac/build.sh               # → ~/Desktop/Albrhi-Mirror/viewer   (+ /tmp/albrhi-mirror-test/mirrord-host, a TEST build)
bash experiments/mirror/test.sh                    # the control and pairing story against the test build
```

The build proves the flavour from the staged paths (no `var/jb` in a roothide package; the app and the daemon present in both).
The Mac needs `iproxy` (`brew install libusbmuxd`).

**Tested on the Mac**, against the daemon's host build (`mirrord-host`, which sends a moving test picture and is **not** the phone's
daemon; it is kept out of the Desktop folder on purpose): off by default; `pair-start` refused while off; a pairing request with no
window open refused; wrong codes burn the three tries and close the window; the right code pairs (the same secret on both sides, both
files `0600`) and works once; an authenticated session; switching off ends a running session and refuses the next; unpair; a Mac with a
wrong secret, an impostor daemon, a client with a bad proof or none; and the install scripts with a stand-in `jbroot`/`launchctl`.
**The app was run in the iOS Simulator against that host daemon**: off → on from the switch → *Pair a Mac* → the code appears with its
countdown → typing it on the Mac pairs → the screen says *A Mac is connected*; the Arabic layout was checked right to left.
**Not tested on a phone**, and therefore not known: whether the capture works, whether `launchctl load` accepts the plist on this
jailbreak, whether `uicache` registers the app, whether the service survives a restart, whether the app (as mobile, without a sandbox)
can reach the socket, and whether any of it survives the phone locking.

If the viewer shows a coloured moving pattern and `iOS (host test build, no iPhone)`, it is talking to the Mac test build and not the
phone: `pkill mirrord-host`.

## Trying it on the phone

1. Install `com.albrhi.mirror.probe_0.3.0_iphoneos-arm64e_roothide.deb`. The service starts by itself and **Albrhi Mirror** appears on
   the home screen (if the icon does not, say so — `uicache` is the first suspect). **Do not start the daemon by hand.**
2. Open the app and turn on **Allow mirroring**. (If it says the service is not running: `launchctl list | grep mirrord` and
   `cat /tmp/albrhi-mirrord.log`.)
3. Plug the phone in by USB, unlocked and trusted. On the Mac open `~/Desktop/Albrhi-Mirror/viewer`.
4. In the app tap **Pair a Mac**; the code appears. Type it in the window on the Mac. After that, opening the viewer is enough.

### What to try, and what to send back

Take a screenshot of the viewer window (it shows the numbers) in each state:

| | what to do | what it tells us |
|---|---|---|
| **A** | phone unlocked, screen on; swipe around | does capture work at all; does the picture change (`CHANGED`); capture time |
| **B** | press the side button (screen off, locked) and wait 5 s | does it keep rendering; `LOCK STATE`; does the picture freeze, go black, or show the lock screen; **did the daemon survive** |
| **C** | raise or tap the screen to show the lock screen, without unlocking | what is captured on the lock screen |

Also send any line that starts with `CAPTURE ERROR`, and `cat /tmp/albrhi-mirrord.log` if something did not start. To undo
everything: remove the package (it stops the service, forgets the pairing and removes the app); on the Mac `viewer --forget`.

## What comes next, only if A and B come back usable

2. H.264 instead of JPEG (VideoToolbox). 3. Touch injection (BackBoardServices / IOHID). 4. Encryption, then and only then a LAN
listener. 5. Keeping the phone usable while "locked": whether that is a dark but awake screen, a cover, or something else depends
entirely on what B shows — it is not decided here.
