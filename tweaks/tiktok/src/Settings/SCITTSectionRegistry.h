//
//  SCITTSectionRegistry.h
//  Albrhi for TikTok
//
//  The settings screen, composed from files that register themselves.
//
//  **Why this shape.** `SCITTStatus.m` held every row of every section in one 220-line array
//  literal inside one method: adding a feature meant editing the middle of a list, deleting one
//  meant counting braces, and reading it meant scrolling past six sections to reach the seventh.
//  The Instagram tweak solved this once already — `SCISettingsRegistry`, one file per page, no
//  shared file to edit — and this is the same idea at section granularity.
//
//  A section appears because its file registered it. Delete the file and the section is gone, with
//  nothing else to change; add one and it slots in at its own order. **No parallel list decides
//  what exists**, which is the failure this project met three times in one week — a title array, a
//  destination array and a row count that drifted apart.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


//
// **The vocabulary a section is written in, declared once.**
//
// These were file-local `static`s inside SCITTStatus.m, which is exactly why a section could not
// live anywhere else: the keys its dictionary is built from were not visible outside that file.
// SCITTReport.m keeps its own copies for its own table and is left alone -- one move at a time.
//
extern NSString *const kSCIKindSwitch;
extern NSString *const kSCIKindLink;
extern NSString *const kSCIRowKind;
extern NSString *const kSCIRowTitle;
extern NSString *const kSCIRowNote;
extern NSString *const kSCIRowIcon;
extern NSString *const kSCIRowColor;
extern NSString *const kSCIRowPref;
extern NSString *const kSCIRowWarns;
extern NSString *const kSCIRowDestination;
extern NSString *const kSCIDestinationReport;
extern NSString *const kSCIDestinationWelcome;

extern NSString *const kSCISectionTitle;
/// Optional. What the section's own row looks like on the root screen -- an SF Symbol name and a
/// tint. A section without them still gets a row; it borrows the icon of its first switch.
extern NSString *const kSCISectionIcon;
extern NSString *const kSCISectionColor;
extern NSString *const kSCISectionRows;

/// Registers one section. Called from a `+load` in the section's own file, so registration happens
/// before any screen is built and needs no list anywhere else.
///
/// @param order  where it sits. Gaps are deliberate: a new section between two others needs a
///               number, not a renumbering of everything after it.
/// @param builder  returns the section dictionary. A block rather than a value because
///                 `SCILocalized` must run after the language is known, not at load time.
void SCITTRegisterSection(NSInteger order, NSDictionary *(^builder)(void));

/// Every registered section, in order. Built fresh on each call: a switch changed on one screen
/// must not be described by a dictionary built before it moved.
NSArray<NSDictionary *> *SCITTSections(void);

NS_ASSUME_NONNULL_END
