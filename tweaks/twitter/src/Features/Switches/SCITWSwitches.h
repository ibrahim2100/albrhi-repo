//
//  SCITWSwitches.h
//  Albrhi for Twitter
//
//  The one place X decides what the app is allowed to do.
//
//  X does not scatter its feature decisions through its screens. Every part of the app
//  asks a switch provider a yes/no question by name -- `-boolForKey:` -- and then obeys
//  the answer. Three classes answer that question in 12.15, and between them they gate
//  a large part of what the app shows.
//
//  **That is why this tweak starts here and not at a view.** A hook on a view stops
//  working the day X renames the view, and this project has already paid for that lesson
//  twice on Instagram. A hook on the decision keeps working while the screens move around
//  above it, because the decision is what the screens are reading.
//
//  ## And why it reports before it changes
//
//  Nobody -- not this project, not the tweaks it was found from -- has a trustworthy list
//  of what each key means. The app binary carries thousands of lowercase underscored
//  strings and only some of them are switches; a table written from reading that binary is
//  a table of guesses, and shipping guesses that silently change an app is exactly the
//  failure this repository keeps writing rules about.
//
//  So the recorder is the feature. Every key the app really asked for on a real phone, the
//  answer it was given, and how often it asked. What that list contains after a release
//  decides what the next release turns on by name.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// What the user has decided about one key.
typedef NS_ENUM(NSInteger, SCITWOverride) {
    /// X's own answer is passed through untouched. The default for every key.
    SCITWOverrideNone = 0,
    SCITWOverrideOff  = 1,
    SCITWOverrideOn   = 2,
};

/// One switch, as this device actually used it.
@interface SCITWSwitchRecord : NSObject
@property (nonatomic, copy) NSString *key;
/// How many times the app asked. The interesting number: a key asked four hundred times
/// during a scroll is load-bearing, and one asked once at launch is probably not.
@property (nonatomic, assign) NSUInteger asked;
/// What X itself last answered, before any override was applied. Kept separately from the
/// override so the settings screen can show both -- "X says on, you say off" is a
/// different situation from "X says off", and they look identical if only one is stored.
@property (nonatomic, assign) BOOL appAnswer;
/// Which of the provider classes was asked. Recorded because two of them can be asked the
/// same key, and knowing which one answers in practice is what a future hook needs.
@property (nonatomic, copy) NSString *provider;
@end


@interface SCITWSwitches : NSObject

/// The hot path, called from `-boolForKey:` on every provider.
///
/// Records the question and returns whether to answer it differently. Written to be cheap:
/// one lock, one dictionary lookup, one counter. It runs thousands of times during a
/// scroll, so anything expensive here is felt as the app being slow rather than seen as a
/// bug in this file.
///
/// Returns NO -- and leaves `answer` untouched -- unless the user set an override.
+ (BOOL)interceptKey:(NSString *)key
           appAnswer:(BOOL)appAnswer
            provider:(NSString *)provider
              answer:(BOOL *)answer;

/// Everything seen so far, most asked first.
/// The answer a *typed* getter should give, or nil to leave X's own.
///
/// `-integerForKey:`, `-doubleForKey:` and `-numberForKey:` are asked about keys that are not
/// booleans at all (a timeout in seconds, a duration threshold), and a feature that needs
/// one -- "do not refresh after the app was in the background", "no auto-advance" -- has no
/// bool to flip. The same two maps answer, hand-set first, but nothing is *recorded* here:
/// the recorder is the list of questions X asks as yes or no, and a typed read of a
/// feature's own key would only double every count.
+ (nullable NSNumber *)numberOverrideForKey:(NSString *)key;

+ (NSArray<SCITWSwitchRecord *> *)records;

/// How many questions have been asked in total, across every key.
+ (NSUInteger)totalAsked;

/// What the user set by hand, for this key alone.
///
/// A hand-set answer always beats a named feature. Somebody who turns on "hide ads" and
/// then sets one of its keys back is saying something more specific than the feature is,
/// and the more specific instruction wins -- the alternative is a switch that flips itself
/// back and no way to tell why.
+ (SCITWOverride)overrideForKey:(NSString *)key;
+ (void)setOverride:(SCITWOverride)override forKey:(NSString *)key;

/// The layer the named features contribute, replaced wholesale each time any of them
/// changes.
///
/// Wholesale rather than added to and removed from: turning a feature off would otherwise
/// mean deleting its keys, but only the ones no other enabled feature also wants, and only
/// where the user has not since set one by hand. Recomputing the whole map from the
/// features that are on has none of that to get wrong.
///
/// Not persisted. It is derived from preferences that are, and storing a derived thing is
/// how the two drift apart.
+ (void)setFeatureOverrides:(NSDictionary<NSString *, NSNumber *> *)overrides;
+ (NSDictionary<NSString *, NSNumber *> *)featureOverrides;

/// Every key the user has an opinion about. Survives a restart; the records do not, and
/// deliberately -- a list of what X asked is only true of the session that observed it.
+ (NSDictionary<NSString *, NSNumber *> *)allOverrides;
+ (void)clearOverrides;

/// Which provider classes were found and hooked, for the diagnostics page.
+ (void)noteProvider:(NSString *)name;
+ (NSArray<NSString *> *)attachedProviders;

@end

NS_ASSUME_NONNULL_END
