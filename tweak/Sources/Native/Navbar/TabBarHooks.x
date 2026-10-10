// What drives the native look's navbar: Spotify's tab bar composed on its layout passes (Navbar.x), and
// holding Home opens Mod Settings.
//
// Tree (trees/home.txt): NavigationUI_TabBarImpl.TabBarView > TabBarCompactView > UIStackView of
//   ElementContentView<TabBarItemElement>, each with an SPTEncoreIconView and an SPTEncoreLabel.
#import "Core/SGCore.h"
#import "Navbar.h"
#import "Settings/SGPage.h"

@interface SGHomeHold : UILongPressGestureRecognizer
@end

@implementation SGHomeHold
+ (void)held:(SGHomeHold *)hold {
    if (hold.state == UIGestureRecognizerStateBegan) SGOpenModSettings(hold.view);
}
@end

// On Spotify's own bar a hold that begins fails the item's tap recognizer, so Home is not tapped too.
static void holdHome(UIView *stockBar) {
    UIView *home = SGRowIn(stockBar).arrangedSubviews.firstObject;
    if (!home) return;
    for (UIGestureRecognizer *recognizer in home.gestureRecognizers) {
        if ([recognizer isKindOfClass:SGHomeHold.class]) return;
    }
    [home addGestureRecognizer:[[SGHomeHold alloc] initWithTarget:SGHomeHold.class action:@selector(held:)]];
}

static UIView *tabBarOf(UIView *item) {
    Class barClass = NSClassFromString(@"_TtC23NavigationUI_TabBarImpl10TabBarView");
    for (UIView *v = item.superview; v; v = v.superview) if ([v isKindOfClass:barClass]) return v;
    return nil;
}

static void updateTabBar(UIView *bar) {
    SGComposeTabBar(bar);
    holdHome(bar);
    SGLogTabBarRow(bar);
}

// Spotify lays out the bar and each arriving item in one turn; one composition sees the settled row.
static char kPendingUpdateKey;
static void requestTabBarUpdate(UIView *bar) {
    if (!bar || [objc_getAssociatedObject(bar, &kPendingUpdateKey) boolValue]) return;
    objc_setAssociatedObject(bar, &kPendingUpdateKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIView *weakBar = bar;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *liveBar = weakBar;
        if (!liveBar) return;
        objc_setAssociatedObject(liveBar, &kPendingUpdateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        updateTabBar(liveBar);
    });
}

%hook _TtC23NavigationUI_TabBarImpl10TabBarView
- (void)layoutSubviews {
    %orig;
    requestTabBarUpdate((UIView *)self);
}
%end

// The bar's own pass runs before Spotify has filled the row; the items lay out as they arrive.
static void itemDidLayOut(UIView *item) {
    UIView *bar = tabBarOf(item);
    requestTabBarUpdate(bar);
}

%hook _TtC23NavigationUI_TabBarImpl21TabBarItemElementView
- (void)layoutSubviews {
    %orig;
    itemDidLayOut((UIView *)self);
}
%end

%hook _TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView
- (void)layoutSubviews {
    %orig;
    itemDidLayOut((UIView *)self);
}
%end

%ctor {
    if (!SGNativeUI()) return;
    %init;
    SGRequireClasses(@[
        @"_TtC23NavigationUI_TabBarImpl10TabBarView",
        @"_TtC23NavigationUI_TabBarImpl21TabBarItemElementView",
        @"_TtC25CreateMenu_TabBarItemImpl24CreateMenuTabBarItemView",
    ]);
}
