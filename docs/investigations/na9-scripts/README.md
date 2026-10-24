# Scripts behind `../na9-analysis.md`

Written for one session, kept so the numbers in the analysis can be reproduced. **They hard-code paths** (the unpacked
deb under a scratchpad, `dis.txt` from `objdump -d --arch=arm64 --no-show-raw-insn`, dumps from `tools/objc-classes.py --dump`)
and are not maintained tools; edit the paths before running.

| file | what it does |
|---|---|
| `emu.py` | a 150-line partial emulator of NA9's string obfuscation (byte-wise XOR with constants held in registers) that follows `adrp`/`add`/`mov`/`eor`/`ldrb`/`strb`/`ldr` linearly, resolves the nested `stp; bl; ldp; ret` trampolines, and prints every `MSHookMessageEx(class, selector, replacement, &orig)` with the class and selector decoded |
| `annot.py` | the same emulator, printing for an address range the selectors sent, class references and decoded strings (how the Settings recipe was read) |
| `vocab.py` | per hook, the selectors and classes its body names |
| `callers.py` | **who calls a selector** in a Mach-O: finds the selref slot, then every `adrp`+`ldr` of it in `__text` (tracking the register), and names the nearest preceding ObjC method; this is what showed that nothing reads `addFollowsYouLabelEnabled` |
| `objc_allimps.py` | `tools/objc-classes.py --dump` that records every method's IMP address (input of `callers.py`) |
| `enc_audit.py` | compares every `%hook` signature in the tweak with the real type encoding in a dump |
