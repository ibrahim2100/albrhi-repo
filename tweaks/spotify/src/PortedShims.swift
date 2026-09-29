//
//  PortedShims.swift
//  Albrhi for Spotify
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

import Foundation

///
/// The handful of names the ported files expect to find, kept here rather than edited into them.
///
/// **The copies stay diffable against upstream on purpose** — the same decision Albrhi NextUp made
/// about its own port, and the reason a later fix from that project can be read against ours
/// instead of hunted for. So where a ported file says `EeveeSpotify.version` or
/// `UserDefaults.cleanShareLinks`, the name is provided here rather than renamed there.
///
///
/// Upstream's debug logger, deliberately not a file.
///
/// **It wrote every message to a file in the app's temporary directory, forever.** Albrhi NextUp's
/// own port carried the same shape and this project switched it off for the same reason: a log that
/// records what somebody is listening to, growing without limit, from a tweak whose neighbours here
/// exist to stop watching being reported at all. `NSLog` is bounded by the system and reaches the
/// console when somebody is actually looking.
///
///
/// **And now not even that unless asked.** `NSLog` is bounded, but it is still a line per event into
/// the system log of a phone whose owner did not ask for one, from thirty-odd call sites that
/// include per-track and per-ad ones. Off unless the app's own defaults carry
/// `albrhi_verbose_logging` -- read once per launch, so leaving it off costs one already-decided
/// boolean per call. Startup lines ("hook activated", once each) are unaffected and stay.
let albrhiVerboseLogging: Bool = UserDefaults.standard.bool(forKey: "albrhi_verbose_logging")

func writeDebugLog(_ message: String) {
    guard albrhiVerboseLogging else { return }
    NSLog("[AlbrhiSpotify] %@", message)
}

enum EeveeSpotify {
    /// Sent to SponsorBlock's API as this client's version. **Ours, not theirs**: it identifies who
    /// is asking, and answering with a version this build is not would misreport a real service.
    static let version = SCIVersionString.replacingOccurrences(of: "v", with: "")
}

//
// **Clean share links was removed in 0.2.1 and its switch with it.** Its three hooks were the only
// ungrouped ones in the port -- Orion installs those at startup, before any gate is consulted -- so
// they ran even with Albrhi's master switch off, and Spotify crashed. Kept out rather than kept
// behind a switch that could not reach them.
//
