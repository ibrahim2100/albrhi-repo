//
//  SCILinkTracking.h
//  Albrhi for Instagram
//
//  Taking the tracking out of a link Instagram hands to somebody else.
//
//  A link copied or shared from Instagram carries `?igsh=<id>` (older builds `igshid`): an
//  identifier tied to the account that shared it, so whoever follows the link can be connected to
//  whoever sent it. The post is the same without it. This removes that and the usual campaign
//  parameters, **only from Instagram's own addresses and only the parameters listed** -- a link to
//  anywhere else, and every parameter that is not a known tracker, is left exactly as it was.
//
//  Pure Foundation, no UIKit, so it runs on the build machine against `tests/host`.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// `urlString` without its tracking parameters when it is an Instagram address; the identical
/// string (same object) when it is anything else or has nothing to remove.
NSString *SCIStripTrackingFromURLString(NSString *urlString);

/// Every Instagram address inside `text` cleaned, the words around them untouched. Punctuation
/// that closes a sentence after a link ("…/p/abc/?igsh=x.") is not part of the link.
NSString *SCIStripTrackingFromText(NSString *text);

NS_ASSUME_NONNULL_END
