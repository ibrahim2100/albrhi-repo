#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCISymbol.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SCITableCell) {
        SCITableCellStatic,
        SCITableCellLink,
        SCITableCellSwitch,
        SCITableCellStepper,
        SCITableCellButton,
        SCITableCellMenu,
        SCITableCellNavigation,
};

///

@interface SCISetting : NSObject

@property (nonatomic, readonly) SCITableCell type;

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;

@property (nonatomic, strong, nullable) SCISymbol *icon;
@property (nonatomic, strong) NSString *defaultsKey;

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURL *imageUrl;

@property (nonatomic) BOOL requiresRestart;

@property (nonatomic) double min;
@property (nonatomic) double max;
@property (nonatomic) double step;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *singularLabel;

@property (nonatomic, copy) void (^action)(void);

@property (nonatomic, strong) UIMenu *baseMenu;

@property (nonatomic, strong) NSArray *navSections;

/// A subtitle worked out when the row is drawn rather than when it was built.
///
/// A checklist row says "3 of 12 on", and that changes in a screen the row opened, after the
/// page holding it was built. The screen redraws when it reappears, so a block is what keeps the
/// count true; a string captured at build time would show the number from before you toggled.
@property (nonatomic, copy, nullable) NSString *(^subtitleBlock)(void);
@property (nonatomic, strong) UIViewController *navViewController;

+ (instancetype)staticCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                               icon:(nullable SCISymbol *)icon;

+ (instancetype)linkCellWithTitle:(NSString *)title
                         subtitle:(NSString *)subtitle
                             icon:(nullable SCISymbol *)icon
                              url:(NSString *)url;

+ (instancetype)linkCellWithTitle:(NSString *)title
                         subtitle:(NSString *)subtitle
                         imageUrl:(NSString *)imageUrl
                              url:(NSString *)url;

+ (instancetype)switchCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                        defaultsKey:(NSString *)defaultsKey;

+ (instancetype)switchCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                        defaultsKey:(NSString *)defaultsKey
                    requiresRestart:(BOOL)requiresRestart;

+ (instancetype)stepperCellWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                         defaultsKey:(NSString *)defaultsKey
                                 min:(double)min
                                 max:(double)max
                                step:(double)step
                               label:(NSString *)label
                       singularLabel:(NSString *)singularLabel;

+ (instancetype)buttonCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                               icon:(nullable SCISymbol *)icon
                             action:(void (^)(void))action;

+ (instancetype)menuCellWithTitle:(NSString *)title
                         subtitle:(NSString *)subtitle
                             menu:(UIMenu *)menu;

+ (instancetype)navigationCellWithTitle:(NSString *)title
                               subtitle:(NSString *)subtitle
                                   icon:(nullable SCISymbol *)icon
                            navSections:(NSArray *)navSections;

+ (instancetype)navigationCellWithTitle:(NSString *)title
                               subtitle:(NSString *)subtitle
                                   icon:(nullable SCISymbol *)icon
                         viewController:(UIViewController *)viewController;


/// Many related switches behind one row.
///
/// A navigation row whose screen is the switches, and whose subtitle counts how many are on.
/// Every switch is still its own preference, exactly as before -- the keys, the defaults, the
/// restart prompts and the search results are all unchanged; only where they are listed moved.
/// For the groups that were a dozen near-identical rows on a page (what to confirm, which tabs to
/// hide, which suggestions to remove), where the question is "which of these", not "this one".
+ (instancetype)checklistCellWithTitle:(NSString *)title
                                  icon:(nullable SCISymbol *)icon
                                 items:(NSArray<SCISetting *> *)items;

+ (instancetype)checklistCellWithTitle:(NSString *)title
                                  icon:(nullable SCISymbol *)icon
                              sections:(NSArray *)sections;


# pragma mark - Instance methods

- (UIMenu *)menuForButton:(UIButton *)button;

@end

NS_ASSUME_NONNULL_END
