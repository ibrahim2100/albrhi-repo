---
name: ios-logos-tweak
description: House style for every Logos file in the Albrhi repository (.x/.xm, %hook, %hookf, %new, %orig, %init, %group): read BEFORE writing or reviewing any tweak code here. PoomSmart's ios-logos-tweak skill (MIT) with a block of Albrhi rules on top that say which of its rules apply as written and which are overridden by something measured on a device. Rootless, roothide and sideload builds.
---

# Albrhi — how this repository writes Logos

**This skill is the foundation for hooking code in this repository.** Its body below is PoomSmart's
[`ios-logos-tweak`](https://github.com/PoomSmart/ios-logos-tweak) (MIT, `LICENSE` beside this file),
copied **unchanged** from commit `8d9f6e142e03fbbad56494c18baf35cc84fb0d09` (2026-10-31) so that it can be diffed
against upstream; everything Albrhi-specific is in this block, above the line. AGENTS.md §4.8 is the same
content in the project's own voice, and `tools/check.py` rules 27 and 28 enforce the parts a machine can read.

## What applies as written

| upstream rule | here |
|---|---|
| hooks are Logos (`%hook`, `%hookf`), not hand-written `MSHook*` | yes for every hook whose class and selector are fixed. New code starts here. |
| `.x` by default, `.xm` only for C++ | yes |
| **`%new(typeencoding)` always written out** | **yes, enforced** (check.py 27). `python3 tools/logos-new-encodings.py --apply <file>` fills it in from what Logos itself computes and `--check <dir>` proves every written encoding equals that. NextUp (a verbatim GPL port, kept diffable against upstream) is the one exception. |
| **`MSFindSymbol(MSGetImageByName(path), …)`, never `MSFindSymbol(NULL, …)`** | **yes, enforced** (check.py 28) |
| `%property` for state a tweak adds to a hooked class | yes for new code; do not rewrite working `objc_setAssociatedObject` sites for its own sake |
| `%init(Class = objc_getClass("…"))` for Swift-mangled / renamed classes | **yes — this is how Instagram 450 is supported** (§5.1; `SCIClassNamed` in `tweaks/instagram`). The old name is asked first, so a build that still has it behaves exactly as before. |
| one `%hook` per class per group, `%end` always, explicit `%init` for every `%group` | yes (check.py rules 2, 12) |
| no `#include <substrate.h>` in Logos files | yes |

## What is overridden, and the measurement behind it

1. **"No `respondsToSelector:` when the OS floor guarantees the method."** Our floor is the *app's* build, not iOS, and apps change selectors between releases. A hook is installed only after `class_getInstanceMethod` **and the type encoding** match (AGENTS.md §4.2: TikTok died on a probe declared `(double)` whose real encoding was `v48@0:8@16d24^q32@40`). Keep the check.
2. **"Bracket messaging, never `objc_msgSend`."** Brackets with a declared `@interface` are right when the selector is confirmed in every supported build. Where the signature is a guess about builds, the cast is taken **from the runtime type encoding** (an `objc_msgSend` cast of the wrong return type crashed TikTok; a wrong `@interface` does the same silently). Do not mass-convert.
3. **"`MSHookIvar` instead of `object_getIvar`."** `MSHookIvar<T>` trusts a type you assert and needs C++; the repository reads foreign state through `SCISafeValueForKey` / `SCISafeNumberForKey` (`shared/src/SCIKVC.h`, check.py rule 23) and `object_getIvar` only when the runtime says the ivar holds an object. Not a style choice: `-valueForKey:` on somebody else's object ran app code and crashed Instagram.
4. **"Never hand-write `MSHookMessageEx`."** A few installs are conditional on the encoding found at run time and on a counter (TikTok, YouTube, X). Logos cannot say "only if the encoding is `v24@0:8@16`". Those are written by hand, behind the check, and report installed / class absent / method absent / encoding found.
5. **"`@available` / version `%group`s."** The axis that matters is the app build; gates here are per capability (class present, selector present), not per iOS version. NextUp, which really does vary by iOS major, gates its hook files by it.

## Rootless, roothide, sideload — nothing in the skill is flavour-specific, and that is the point

Logos output is identical for all three. The flavour is decided **by which Theos stages the package** (`tools/build-local.sh`
proves it from the staged paths) and, at run time, by `dladdr` on this code's own address (`SCIPanelGate`) — never by a
path typed into the source. **No `/var/jb` literal anywhere; the only `/Library/MobileSubstrate/` strings are NextUp's two lines that derive the install location from the dylib's own path; the only `jbroot()` is Spotify's C shim (`AlbrhiSpotifyC.m`)**;
`tools/doctor.sh` and AGENTS.md §3.4 say how each flavour is built. A standalone dylib (sideload) has no Substrate: it carries
`SCISubstrateShim.m` and `build-dylibs.sh` fails the build on an undefined `MS*` symbol.

## Review checklist (upstream's, plus ours)

Run the upstream checklist at the bottom, then: `python3 tools/check.py` (27 and 28 are this skill), `python3 tools/logos-new-encodings.py --check tweaks`,
`bash tools/run-host-tests.sh`, and for a renamed class `python3 tools/objc-diff.py --check <build> --tweak tweaks/<x>`.

---

# Upstream text (unchanged)

# iOS Logos Tweak Best Practices (upstream)

## Core rule

Put hooking code in **Logos files** (`.x`, `.xm`, `.xi`) and express hooks with **Logos directives**. Let the Logos preprocessor emit `MSHookMessageEx`, `MSHookFunction`, `class_addMethod`, constructors, and class registration.

Do **not** hand-write Substrate hook boilerplate in tweak source unless Logos cannot express the case (rare; see [reference.md](reference.md)).

## File layout

**Default: `.x`.** Most tweaks use a single `Tweak.x` (Logos + Objective-C). Theos runs Logos on the file, then compiles the result as ObjC.

| Extension | Compiles as | When to use |
|-----------|-------------|-------------|
| **`.x`** | Objective-C | **Default.** `%hook`, `%hookf`, `%new`, `%orig`, `%property`, blocks, and normal Foundation/UIKit code. |
| **`.xm`** | Objective-C++ | Only when this **translation unit** needs C++ or Substrate’s C++ APIs (see below). |
| **`.xi` / `.xmi`** | Included fragments | Rare: Logos inside `#define` macros or `#include` chains; prefer splitting into separate `.x`/`.xm` files with `extern` instead ([Theos docs](https://theos.dev/docs/logos-file-extensions)). |

### Use `.xm` when this file contains

- **`MSHookIvar<T>`** or **`MSIvarHook`** (implemented as C++ templates in `<substrate.h>`).
- **C++** only valid in ObjC++: `std::`, `namespace`, templates, lambdas, C++ types in hook bodies.
- **`%orig`** forms that embed **block literals** in the hook implementation when your toolchain/setup requires ObjC++ for those expansions (uncommon; most hooks stay in `.x`).

### Stay on `.x` when

- Hooks are plain Objective-C (even with blocks, `@autoreleasepool`, etc.).
- You do not call `MSHookIvar` in that file.

If only one hook file needs ivar access, keep **`Tweak.x`** and add a small **`Something.xm`** (or move just those hooks to `.xm`) rather than renaming the whole project to `.xm` without reason.

Keep **interfaces and constants** in normal `.h` / `.m` when they are not hooks. Keep **all hooks** in Logos (`.x` / `.xm`, not raw `.m` with `MSHook*`).

Do not `#include <substrate.h>` in Logos files; Theos/Logos adds it in generated code.

## Objective-C methods: `%hook`

```logos
%hook YTPlayerViewController

- (void)layoutSubviews {
    %orig;
    // tweak logic
}

%end
```

- Match the **exact** selector signature (class vs instance `+`/`-`, types, argument names).
- Call the original with `%orig` or `%orig(arg1, arg2)`; never pass `self` or `_cmd`.
- If you use `%orig(...)`, pass **every** user argument (Logos fills `self`/`_cmd`).
- Always close with `%end`.

**Avoid:** `MSHookMessageEx`, `method_setImplementation`, `method_exchangeImplementations`, or IMP trampolines for methods Logos can hook.

## Objective-C messaging

Send messages with **`[receiver message]`** / **`[receiver foo:bar]`** syntax. Do not use `objc_msgSend`, `objc_msgSendSuper`, or similar runtime send helpers for calls you can express as normal Objective-C.

If a symbol is undeclared in the public SDK, add a **private header** or class/category `@interface` with the method, then call it with brackets. That keeps type checking and ARC rules; `objc_msgSend` needs manual casts, is easy to get wrong on arm64, and reads worse than idiomatic ObjC.

**Avoid:** `((void (*)(id, SEL, ...))objc_msgSend)(obj, @selector(foo), arg)` when `[obj foo:arg]` (after a proper declaration) works.

## C functions: `%hookf`

```logos
%hookf(BOOL, MGGetBoolAnswer, CFStringRef string) {
    if (CFEqual(string, CFSTR("SomeKey"))) return YES;
    return %orig;
}
```

- First argument is return type; second is the **symbol name**; rest are parameters (no implicit `self`/`_cmd`).
- For private symbols, resolve at init time with **`MSFindSymbol(MSGetImageByName(...), "_symbol")`**. Pass the **image that owns the symbol** as the first argument to `MSFindSymbol`; do not pass `NULL`.

```logos
%ctor {
    void *gestalt = MSGetImageByName("/usr/lib/libMobileGestalt.dylib");
    %init(MGGetBoolAnswer = MSFindSymbol(gestalt, "_MGGetBoolAnswer"));
}
```

- **`MSFindSymbol(NULL, name)`** searches every loaded image. That pattern is **discouraged**: some runtime modification / injection setups can crash or behave badly during global symbol lookup. Always **`MSGetImageByName("/path/to/Image.dylib")`** (framework binary path as Substrate expects) and pass that `MSImageRef` to `MSFindSymbol`.
- If lookup fails, guard before `%init` (skip the group or log) rather than passing a null pointer into `%init`.

**Avoid:** `MSHookFunction` + manual replacement when `%hookf` + `%init` suffices; **`MSFindSymbol(NULL, ...)`** for dynamic `%hookf` targets.

## New methods and storage: `%new` and `%property`

Add methods on an existing class inside `%hook`:

```logos
%hook MyTargetClass

%new(v@:@)
- (void)myTweak_didTap:(id)sender {
    // no %orig — method did not exist before
}

%property (nonatomic, strong) UIView *myTweak_overlay;

%end
```

- Use `%new` for any method that **does not exist** on the class (including helpers only your tweak calls).
- Always write **`%new(typeencoding)`** with the **exact** Objective-C method type encoding (e.g. `%new(v@:)` for `- (void)foo`, `%new(v@:@)` for `- (void)foo:(id)x`, `%new(@@:)` for `- (id)bar`). Bare `%new` without parentheses makes Logos **generate** an encoding from the declaration; that extra work is unnecessary when you already know the signature.
- Match the encoding to the method you declare; when unsure, compile a stub and read `@encode` / `method_getTypeEncoding`, or copy from a class dump for the same selector shape.
- Use `%property` for associated state on hooked classes instead of `objc_setAssociatedObject` in every hook (unless you need fine-grained control).

**Avoid:** `class_addMethod` + static C functions for tweak-only ObjC methods on hooked classes.

## Instance variables: `MSHookIvar`

In **tweak dylib code** linked against Cydia Substrate (Logos `.x`/`.xm`, or `.m`/`.xm` helpers in the tweak target), read and write the target app’s **existing** ivars with **`MSHookIvar`** from `<substrate.h>` (included automatically in Logos output). Do not reimplement access with `class_getInstanceVariable`, `ivar_getOffset`, manual `((char *)self + offset)`, `object_getIvar`, or `object_setIvar` unless Substrate is unavailable.

```logos
%hook SomeViewController

- (void)viewDidLoad {
    %orig;
    UIView *content = MSHookIvar<UIView *>(self, "_contentView");
    content.hidden = NO;
}

%end
```

Inside a hook body, the **`MSIvarHook(type, name)`** macro (Substrate) is equivalent to a typed reference for an ivar whose **name matches** the stringized token (e.g. `MSIvarHook(UIView *, _contentView)`).

- Use **`.xm`** for this file if it uses **`MSHookIvar`** / **`MSIvarHook`**; otherwise keep ivar-free hooks in **`.x`**.
- For **state your tweak adds**, prefer **`%property`** on the hooked class, not reading/writing foreign ivars you invent.
- In targets **without** Substrate (preference bundles, standalone tools, libraries not injected into processes), use the Objective-C runtime ivar APIs or public accessors; do not assume `MSHookIvar` is linked.

**Avoid:** offset hunting duplicated in every call site when the tweak already links Substrate.

## When hooks run: `%group`, `%ctor`, `%init`

- Ungrouped `%hook` / `%hookf` → default group; Logos emits a constructor that calls `%init` automatically.
- Use `%group` when hooks must be **conditional** or **delayed**:

```logos
%group iOS17
%hook SomeNewClass
- (void)foo { %orig; }
%end
%end

%ctor {
    if (@available(iOS 17, *)) %init(iOS17);
}
```

- Call `%init` or `%init(GroupName)` from `%ctor` (or another function) for grouped hooks; do not rely on auto-init for grouped code.
- Use `%init(ClassName = objc_getClass("Swift.Module.Class"))` for Swift/mangled or awkward class names.

## API availability: version checks vs `respondsToSelector`

Pick **one** primary strategy per code path. Mixing `@available`, `%group`, and `respondsToSelector` on the same feature adds noise without extra safety.

### When the deployment floor already includes the API

If the tweak only runs on iOS versions where the selector **always exists** (declared minimum in the project, or hooks live in a `%group` initialized only on that OS), **call the API directly**. Do not wrap every use in `respondsToSelector:` / `instancesRespondToSelector:` / `+[Class respondsToSelector:]`.

Version gating at init (`%group` + `%init`, `@available` in `%ctor`) is enough; inside those hooks, treat the method as present.

### When runtime checks make sense

Use `respondsToSelector:` (and class-side equivalents) when:

- The tweak supports a **wide OS range** with **few** explicit version checks, and
- A selector appears only on some releases (Apple added a method mid-cycle, private API drift, optional app-internal helpers), and
- You are calling across classes you do not hook (not choosing whether to install a Logos hook).

Example: one optional call on a shared code path without adding `@available(iOS X, *)` at every call site.

```objc
if ([obj respondsToSelector:@selector(newStyleLayout)]) {
    [obj newStyleLayout];
} else {
    [obj legacyLayout];
}
```

Prefer **class** checks (`+[SomeClass instancesRespondToSelector:]`) when the method is implemented on the class, not overridden per instance.

### What to avoid

- `respondsToSelector:` before every message send when `%init(iOS17)` or the package minimum already guarantees the selector.
- `respondsToSelector:` **and** `@available` for the same branch unless they guard different risks (e.g. SDK compile vs runtime on an old binary).
- Using runtime checks instead of `%group` for **entire hook sets** that only apply on one OS; use `%group` + `%init` so hooks are not installed on unsupported versions.

## Other Logos tools (prefer over manual runtime)

| Need | Logos / Substrate |
|------|--------|
| Runtime class reference | `%c(ClassName)` or `%c(+ClassName)` for metaclass |
| Log hook calls | `%log` in a method body |
| Subclass at runtime | `%subclass` + `%property` + `%c()` to allocate |
| Target class private ivar | `MSHookIvar` / `MSIvarHook` in tweak code (not raw runtime offset math) |
| Generator backend | `%config(generator=MobileSubstrate)` (default), `libhooker`, or `internal` |

Note: `%hookf` is **not** supported with `generator=internal`. Pick the generator to match the target jailbreak environment.

## Code organization

- One `%hook ClassName` block per class; multiple methods inside one block.
- Split large tweaks with `%group` in separate Logos files when using [hook splitting](https://theos.dev/docs/logos-hook-splitting) (`%init` from a shared constructor); use `.x` unless that file needs `.xm` for C++/`MSHookIvar`.
- Declare classes you hook in headers (`@interface`) or private headers; Logos does not replace the need for correct types at compile time.
- Use `logos_interface` / empty `@interface` in `.x` when you need typed calls to `%new` APIs from plain `.m` files.

## Common mistakes

1. **Hooking in `.m` with Substrate** while the rest of the project uses Logos — move hooks into **`Tweak.x`** (or `.xm` only if that file needs ObjC++).
2. **Missing `%end`** or nesting `%hook` inside a method (invalid; Logos errors).
3. **Calling `%orig` in a `%new` method** — unsupported; call super or another selector explicitly if needed.
4. **Forgetting `%init` for `%group`** — hooks never run.
5. **Duplicate hooks** for the same class/method in one group — undefined behavior; merge blocks.
6. **Using `%hookf` inside `%hook`** — `%hookf` is top-level (except inside `%group`).
7. **`objc_msgSend` instead of `[obj msg]`** — declare the API and use bracket syntax.
8. **`ivar_getOffset` / `object_getIvar` in tweak code** — use `MSHookIvar` when Substrate is linked.
9. **Bare `%new` without type encoding** — use `%new(v@:)` (etc.) matching the method signature.
10. **`MSFindSymbol(NULL, …)`** — use `MSFindSymbol(MSGetImageByName("/path/to/dylib"), "_symbol")`.

## Review checklist

When writing or reviewing tweak code:

- [ ] Hooks live in `.x`/`.xm` with `%hook` / `%hookf`, not raw `MSHook*`
- [ ] New tweak methods use `%new(typeencoding)` with exact encodings; ivar-like state uses `%property` where appropriate
- [ ] `%orig` usage is correct; grouped hooks have explicit `%init`
- [ ] Dynamic `%hookf` symbols resolved with **`MSGetImageByName` + `MSFindSymbol(image, …)`**, never `MSFindSymbol(NULL, …)`
- [ ] Default **`Tweak.x`** unless the file uses C++ or `MSHookIvar`; do not use `.xm` “just because”
- [ ] No redundant `respondsToSelector:` where OS floor or `%group` already guarantees the API; runtime checks only where version checks are intentionally light
- [ ] No `objc_msgSend` for normal calls; use `[receiver …]` with headers for private selectors
- [ ] Private ivar access in the tweak dylib uses `MSHookIvar`, not manual runtime offset/`object_getIvar` (runtime OK only in non-Substrate targets)

## Additional resources

- Directive details and edge cases: [reference.md](reference.md)
- Official syntax: https://theos.dev/docs/logos-syntax
