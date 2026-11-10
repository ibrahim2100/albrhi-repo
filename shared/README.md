# shared/

What every tweak in this repository compiles in (`shared/tweak.mk` lists it, so a new file here costs one line there).

| file | what it is for | tested |
|---|---|---|
| `tweak.mk` | Theos flags and the shared sources every tweak gets | built by every tweak |
| `SCIPanelGate` | the master switch and the per-app switch; asked before any hook is installed | — |
| `SCISafeLaunch` (+ `Rule`) | if an app does not start twice in a row the tweak stands down and offers the way back (not in Apple's apps or Instagram) | rule: `tests/host` · launch: simulator |
| `SCICard` | a message card drawn in a window of our own (system alerts and sheets come out mirrored in TikTok on an Arabic account) | simulator |
| `SCIWatchBudget` (+ `Rule`) | a soft daily limit on videos and minutes | rule: `tests/host` · card: simulator |
| `SCIFileName` | one readable, safe file name: `@account - caption - id.ext` | `tests/host` |
| `SCIKVC` | safe reads of other apps' objects (never `-valueForKey:`) | — |
| `SCIMediaSniff` | what a finished download actually is (refuses HTML saved as video) | YouTube host tests |
| `SCIResponder` | finding the responder chain's controllers | — |
| `SCISubstrateShim` | stands in for Substrate in a standalone (sideload) build | build check |
| `Prefs/` | the settings-screen furniture | — |

Run the tests: `bash shared/tests/host/run.sh` (or all of them: `bash tools/run-host-tests.sh`).
