//
//  SCITWTimelineFilter.h
//  Albrhi for X
//
//  Suggestions, topics, trend videos, promoted rows and offers, removed from the section data
//  before the timeline turns them into cells (and hidden as cells where that is all there is).
//
//  **One hook covers all of them, and that is the point.** `TFNItemsDataViewController` is
//  the controller behind every list X draws, and `-tableViewCellForItem:atIndexPath:` hands
//  over the cell it just built for an item whose model `-itemAtIndexPath:` will name. So a
//  module is recognised by the *class of its view model* rather than by reaching into a
//  view hierarchy — which is what the existing promoted filter does, and why that one has
//  to be taught about each surface separately.
//
//  **BHTwitter gates the same hook on `adDisplayLocation`, and that property is not on this
//  class in X 12.20.** So the gate is gone and the model names have to carry the whole
//  decision, which makes them worth stating precisely: a name here matches one kind of
//  module, never a word inside a description. The counts are per feature so a wrong match
//  shows up as the wrong number rather than as a vague "things are missing".
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NSString *SCITWTimelineFilterReport(void);
void SCITWInstallTimelineFilter(void);
