//
//  SCILicense.h
//  Albrhi — shared
//
//  Whether this device is licensed, and what to say when it is not.
//
//  ── What this is honest about ──────────────────────────────────────────────────────────
//
//  **No check that runs on the user's own device can be made unbreakable, and this one is not
//  advertised as such.** The tweak is a dylib on a jailbroken phone; whoever holds the phone
//  holds the file, and a determined person patches the branch. Every commercial tweak with a
//  licence has been cracked, including the ones written by people who do this full time.
//
//  What a licence layer can actually buy:
//
//    1. **Most people do not crack anything.** They pay, or they go without. A lock that a
//       specialist opens in an hour still works on everybody who is not that specialist.
//    2. **Cost.** Verification that is spread out, tied to a real signature and consulted from
//       several places is meaningfully more work to remove than one `if` at launch.
//    3. **Revocation**, which is the part no client-side trick provides: a key that turns up on
//       a forum is named in a list and stops working on every device that reaches the server.
//
//  What it cannot buy is certainty, and building as though it could is how a licence layer ends
//  up breaking things for paying users while the crack circulates anyway. So: it fails toward
//  letting people work, it never crashes an app, and it never blocks on the network.
//
//  ── The design ────────────────────────────────────────────────────────────────────────
//
//  **A signed key that works with no internet, plus a check-in that can revoke it.**
//
//  The key is `ALB1.<payload>.<signature>` — ECDSA P-256 over SHA-256, verified against a public
//  key compiled into every binary. The payload names the device it was issued to and the day it
//  expires. Nothing about it is secret: a licence the buyer can read is one the buyer can check.
//
//  The device is named by a **derived fingerprint** — sixteen hex characters of
//  SHA-256(serial + model + a fixed salt). It is stable across reinstalls and tweak updates,
//  needs nothing written to disk to compute, and is not reversible into a serial number by
//  anyone who receives it. That was the owner's own choice over sending a real UDID.
//
//  Revocation is a periodic call carrying only the licence id and that fingerprint. **One day of
//  grace** if it cannot be reached — the owner's decision, and worth restating plainly because
//  it is short: a phone in airplane mode for two days stops being licensed, which is a support
//  question rather than a bug. `SCILicenseGraceSeconds` below is the one place to change it.
//
//  ── Enforcement, and why it has no switch ─────────────────────────────────────────────
//
//  It is always on. It shipped as a preference for one release so the layer could be introduced
//  before it was enforced — proved end to end on a real device first, which is the right order —
//  and then the preference was removed, because a preference lives in the panel, the panel ships
//  to everybody, and **a licence gate with a user-visible off switch is not a gate**.
//
//  Nobody is locked out by that. The panel never asks the gate, so the screen that enters a
//  licence is always reachable, and an offline key verifies with no network at all. The way back
//  in is entering a licence — which is the only way back in that is not also a way around.
//
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// How this device answers when a key is issued for it. Sixteen lowercase hex characters.
///
/// **Provisioned once and then read, never recomputed per process — and that is a fix, not a
/// preference.** It used to be a hash over the serial number from MobileGestalt, which is
/// entitlement-gated *per process*: Settings can read it and a sandboxed app cannot. So the panel
/// and Instagram computed two different fingerprints for one phone, a key issued from the panel
/// was "for another device" everywhere it mattered, and the panel said `licensed` while every
/// tweak stood down. Measured by forcing the fallback, not inferred.
///
/// **A value not readable from every process is not an identity.** What is stored instead is eight
/// random bytes, written once by the panel into the domain every tweak already reads through
/// `SCIPanelReadString`. It needs no entitlement, it is identical in every process by
/// construction, it survives tweak updates because dpkg leaves that plist alone, and — better
/// than what it replaces — it is not derived from anything about the person or the hardware.
NSString *SCILicenseFingerprint(void);

/// Creates the stored identity if there is none. Called by the panel, which is the one place that
/// can write this domain; a sandboxed tweak may only read it.
void SCILicenseProvisionDevice(void);

/// YES when no stored identity has been provisioned yet, so what `SCILicenseFingerprint()` just
/// answered is a local guess that no other process will agree with.
///
/// A key must not be issued against one: it would fit nothing. The panel says so where the
/// fingerprint is shown, and the gate's report says so where a tweak refuses.
BOOL SCILicenseFingerprintIsWeak(void);

typedef NS_ENUM(NSInteger, SCILicenseState) {
    SCILicenseStateNone = 0,      ///< No key has been entered.
    SCILicenseStateValid,         ///< Signed for this device and in date.
    SCILicenseStateExpired,       ///< Genuine, and its day has passed.
    SCILicenseStateWrongDevice,   ///< Genuine, issued to a different fingerprint.
    SCILicenseStateMalformed,     ///< Not a key at all, or edited.
    SCILicenseStateRevoked,       ///< The server named it.
    SCILicenseStateGrace,         ///< Valid, and the check-in has not succeeded lately.
};

/// The state of the key stored for this device, recomputed on demand.
SCILicenseState SCILicenseCurrentState(void);

/// The one question the tweaks ask.
///
/// YES when enforcement is off (which is the shipped default), and YES when there is a valid
/// key. So a build that has never been given a key behaves exactly as every release before the
/// licence layer existed — which is the direction this has to fail in.
BOOL SCILicenseAllows(void);

/// Whether the gate is actually being applied on this device.
BOOL SCILicenseIsEnforced(void);

/// A human sentence for the panel and for the diagnostics report.
NSString *SCILicenseStatusLine(void);

/// The same sentence for a state that is not the stored one.
///
/// Needed because a key that was *rejected* was never stored: asking for the status line after a
/// refusal would describe whatever key was there before, and tell somebody their brand-new key
/// expired when what actually happened is that it was issued to their other phone. Three
/// refusals need three different things done about them.
NSString *SCILicenseDescribeState(SCILicenseState state);

/// Stores a key after checking it. NO if it is not a key for this device, with `outState` set.
BOOL SCILicenseStoreKey(NSString *key, SCILicenseState *_Nullable outState);

/// The stored key, or nil.
NSString *_Nullable SCILicenseStoredKey(void);

/// Removes it.
void SCILicenseForgetKey(void);

#pragma mark - Asking for a licence

/// A request to paste into the licence panel: this device, the duration wanted, and a note.
///
/// `ALBREQ1.<payload>.<check>` — deliberately not signed, because there is nothing on the device
/// to sign it with and nothing in it worth forging: a request is a *question*, and the person
/// answering it decides. The four-character check is for typos, not for tampering, and it is
/// named that way in the panel so nobody reads it as a signature.
NSString *SCILicenseMakeRequest(NSInteger days, NSString *_Nullable note);


#pragma mark - Redeeming a short code

/// What happened when a code was redeemed.
typedef NS_ENUM(NSInteger, SCILicenseRedeemResult) {
    SCILicenseRedeemedOK = 0,
    SCILicenseRedeemMalformed,     ///< Not the right shape, or a typo the checksum caught.
    SCILicenseRedeemUnknown,       ///< Correctly shaped and not in the published list.
    SCILicenseRedeemWindowClosed,  ///< Real, and its redemption window has passed.
    SCILicenseRedeemOffline,       ///< The list could not be read; nothing was decided.
    SCILicenseRedeemTaken,         ///< Real, and already bound to a different device.
};

/// Redeems a short code like `ALB-4K7M-9QX2-P3RT` and binds it to this device.
///
/// **A short code cannot carry a signature — it is twelve characters.** So the device hashes what
/// was typed and looks that hash up in a list published beside the source. The list holds
/// *hashes*, never codes, so reading it hands nobody a working code; and it is fetched once, at
/// redemption, after which the licence is local and needs no network again.
///
/// The honest limitation, stated here because it cannot be engineered away without a server: an
/// unbound code is shareable until it is removed from that list. Its protections are the
/// redemption window it carries and revocation by hash.
///
/// Asynchronous, and the completion runs on the main thread.
void SCILicenseRedeemCode(NSString *code, void (^completion)(SCILicenseRedeemResult result));

/// The code redeemed on this device, normalised, or nil.
NSString *_Nullable SCILicenseRedeemedCode(void);

/// Forgets it, so another can be entered.
void SCILicenseForgetCode(void);


/// Asks the server whether the stored key is still good, at most once every few hours.
///
/// Never blocks: it returns immediately and the answer lands in the stored state for the next
/// question. Called from the panel and once per launch from the gate.
void SCILicenseCheckInIfDue(void);


#pragma mark - The server

///
/// Where the licence server lives, or nil.
///
/// Read from the panel's own domain rather than compiled in, so a deployment can be pointed
/// somewhere else — or unset — without rebuilding nine tweaks. **Absent means every server
/// feature is simply unavailable and the offline key path works exactly as before**, which is the
/// direction this has to fail in: a licence layer that stops working because a URL was not
/// configured yet would be worse than no server at all.
///
NSString *_Nullable SCILicenseServerBase(void);

/// Points the device at a server. Panel only — a sandboxed app cannot write this domain.

/// What a call to the server came back with.
typedef NS_ENUM(NSInteger, SCILicenseServerResult) {
    SCILicenseServerOK = 0,         ///< A licence arrived and was stored.
    SCILicenseServerNoLicence,      ///< The server knows this device and has nothing for it.
    SCILicenseServerRevoked,        ///< It had one and it was withdrawn.
    SCILicenseServerExpired,        ///< It had one and its term ended.
    SCILicenseServerPending,        ///< A request is waiting for an answer.
    SCILicenseServerUnreachable,    ///< Nothing was decided.
    SCILicenseServerNotConfigured,  ///< No server address on this device.
    SCILicenseServerTrialUsed,      ///< The free week has already been taken on this device.
    SCILicenseServerAlreadyLicensed,///< Asked for a trial while holding a real licence.
};

/// Asks the server for a fresh licence and stores it.
///
/// This is the renewal call. The token the server signs lasts a week, so this failing is not an
/// emergency — there are six days of slack behind it — which is exactly why it never blocks and
/// never reports a network problem as a licence problem.
void SCILicenseSyncWithServer(void (^_Nullable completion)(SCILicenseServerResult result));

/// Takes the free week, once per device.
///
/// **What it cannot promise, and the panel says so too:** the device id is a random value written
/// once, so wiping Albrhi's preferences produces a new id and a second trial. There is no fix that
/// does not involve a real device identifier — deliberately not used here, for privacy and because
/// it is not readable from every process. A convenience for honest people, not a lock.
void SCILicenseStartTrial(void (^completion)(SCILicenseServerResult result));

/// Whether this licence has no end date at all.
///
/// A separate question from `SCILicenseTermEnds`, which answers 0 both for "forever" and for "no
/// licence" — two states that must never be drawn the same way.
BOOL SCILicenseIsLifetime(void);

/// What a licence covers, and whether it covers `product`.
///
/// **Three kinds, and the field they travel in already existed.** Every token has carried `tier`
/// since the server was written, defaulting to `suite`; reading it as a *scope* rather than as a
/// label costs no new field and leaves every licence already issued working exactly as before —
/// absent or `suite` means everything.
///
///   `suite`            the jailbreak licence: Albrhi and every tweak in it.
///   `apps`             the shared code: every separately installed tweak, wherever it runs.
///   `app:<name>`       one tweak alone — `app:youtube`, `app:instagram`, `app:twitter`,
///                      `app:tiktok`.
///
/// `product` is the tweak asking: the same short name the `app:` form uses. A tweak that does not
/// know its own name passes nil, which is answered as "any licence will do" — the behaviour every
/// caller had before this existed.
///
/// A build made for one store, with one licence, on any number of devices.
///
/// **This is a different product from the licence layer beside it, and saying so plainly is the
/// point.** Everything else here is device-bound, revocable and signed: a key names one phone and
/// the server can withdraw it. A store build is the opposite by request — one code, unlimited
/// devices, unlimited people, three months — because what is being sold is a copy in a shop
/// rather than a licence to a person.
///
/// So the honest description of its strength: **the code is compiled into a dylib the store hands
/// out, and anyone holding that dylib can read it.** It cannot be otherwise — a credential that
/// works on any device with no server has nothing left to check against. What it does buy is that
/// the code works on *these* builds and nowhere else, and that they stop by themselves on a date
/// chosen when they were built. It is a shelf life, not a lock.
///
/// Compiled in with `STORE=na9`; absent from every ordinary build, where the code below is not a
/// string that can be typed but a path that does not exist.
NSString *_Nullable SCILicenseStoreID(void);

/// The store's own name and address, for the licence screen.
NSString *_Nullable SCILicenseStoreName(void);
NSString *_Nullable SCILicenseStoreSite(void);

/// When this build stops. Zero in an ordinary build.
NSTimeInterval SCILicenseStoreExpiry(void);

/// Whether `code` is this store's code, and whether the build is still inside its window.
BOOL SCILicenseStoreAccepts(NSString *_Nullable code);

/// Whether the store code has been entered on this device and is still in date.
BOOL SCILicenseStoreActive(void);

/// Remembers a store code that this build accepts. Ignores anything else.
void SCILicenseStoreRemember(NSString *_Nullable code);

/// Sends this build's store code to the server and stores the token it answers with.
///
/// The server decides: whether the code is live, until when, and — the whole reason this is not a
/// date compiled into the dylib — it counts the devices, so the shop can see how far its copies
/// have spread before deciding whether to renew.
void SCILicenseActivateStore(NSString *_Nullable code,
                             void (^completion)(SCILicenseServerResult result));

NSString *SCILicenseScope(void);
BOOL SCILicenseCoversProduct(NSString *_Nullable product);

/// Licensed *and* in scope. This is what a gate should ask; `SCILicenseAllows()` answers only the
/// first half and is kept for the panel, which is not gated by anything.
BOOL SCILicenseAllowsProduct(NSString *_Nullable product);

/// Asks the server for a licence of `days`, on this device's behalf.
///
/// `lifetime` overrides `days`. `name` and `contact` are who to answer — without them the panel
/// is a list of hex strings and approving one means remembering which conversation it belonged
/// to, which is the bookkeeping the panel exists to remove.
void SCILicenseRequestFromServer(NSInteger days, BOOL lifetime,
                                 NSString *_Nullable name, NSString *_Nullable contact,
                                 NSString *_Nullable note,
                                 void (^completion)(SCILicenseServerResult result));

/// Redeems a short code against the server, which binds it to this device.
void SCILicenseRedeemWithServer(NSString *code,
                                void (^completion)(SCILicenseRedeemResult result));

/// When the current licence's *term* ends, as opposed to when its token needs renewing.
/// Zero when there is no licence or it carries no end date.
NSTimeInterval SCILicenseTermEnds(void);

/// How long to wait before asking the server again, as a function of two numbers alone.
///
/// Exposed for one reason: a table of intervals is testable and the code that gathers a token and
/// a term from a device is not. `tokenLeft` is seconds until the signed token expires and is
/// negative when none is stored; `termLeft` is seconds until the licence ends, or
/// `kSCITermForever`.
NSTimeInterval SCICheckIntervalFor(double tokenLeft, double termLeft);
extern const double kSCITermForever;

/// One day, in seconds. The owner's choice, and the single place it lives.
extern const NSTimeInterval SCILicenseGraceSeconds;

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
