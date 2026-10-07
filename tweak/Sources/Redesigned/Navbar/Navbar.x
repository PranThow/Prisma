// The redesign's copy of Native/Navbar/Navbar.x, composing the row the glass tab bar mirrors.
// Navbar: which tabs the bar shows, in what order, and tabs of the mod's own that open any
// spotify: URI. Spotify keeps its four items (Home, Search, Library, Create) as the arranged
// subviews of one stack view, but a tap on one of them is answered by counting the row off from
// the left, not by asking the item what it is: moved in the stack, an item takes the tap of
// whatever used to stand there. So the stack's own order is left exactly as Spotify built it.
//
// The row is split into equal slots instead, and each item is given the frame of its slot after
// the stack's own pass: hit testing goes by frame, so the touch follows the icon, while Spotify
// still counts its items off in the order it put them in. Items of the mod's own go on the end of
// the stack, past that count, and take a slot with the rest. A tap on one goes through Spotify's
// link dispatcher, the same route the app takes for a link it opens itself, so any URI works.
//
// Tree (trees/home.txt): NavigationUI_TabBarImpl.TabBarView > TabBarCompactView > UIStackView
//   402x49 of four ElementContentView<TabBarItemElement> 100x49, each an SPTEncoreIconView 24x24
//   at y 12.5 over an SPTEncoreLabel at y 35.
#import "Core/SGCore.h"
#import "Navbar.h"
#import "Headers/SPTEncoreIconView.h"
#import "Shared/Navigation/Links.h"
#import <objc/message.h>

static const CGFloat kIconSize = 24;
static const CGFloat kIconTop = 12.5;
static const CGFloat kLabelTop = 35;
static const CGFloat kLabelHeight = 14;
static char kCustomKey, kOrderKey, kStockColorKey;

// Where Spotify's own items keep their icon and label, read off one of them every pass, so an item of
// the mod's own sits on the same line as its neighbours.
static CGRect sg_iconBox = {{0, kIconTop}, {kIconSize, kIconSize}};
static CGRect sg_labelBox = {{0, kLabelTop}, {0, kLabelHeight}};

static __weak UIView *sg_navbarRoot;
// The bar's row of items, given its frames by placeRow after each of its own passes.
static __weak UIStackView *sg_row;
static UIFont *sg_tabFont;
static __weak UIControl *sg_selectedCustom;
static BOOL sg_openingCustom;
// Spotify's own tabs in Spotify's order, from the first layout pass of this launch, before
// anything below has moved them.
static NSMutableArray<NSString *> *sg_stockOrder;

static UIColor *itemColor(void) { return [UIColor colorWithWhite:0xB3 / 255.0 alpha:1]; }

#pragma mark - the mod's own items

// One of the 538 glyphs SPTEncoreIcon exposes, one class method each ("podcasts", "heart"), so an
// item of the mod's own is drawn the same way as Spotify's. An SF Symbol stands in if the name is
// not one of them.
static UIView *iconView(NSString *name) {
    Class icon = NSClassFromString(@"SPTEncoreIcon");
    Class view = NSClassFromString(@"SPTEncoreIconView");
    SEL glyphSel = NSSelectorFromString(name.length ? name : @"star");
    if (icon && view && [icon respondsToSelector:glyphSel]) {
        id (*glyphFor)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        id glyph = glyphFor(icon, glyphSel);
        SPTEncoreIconView *encore = glyph ? [[view alloc] initWithIcon:glyph] : nil;
        if (encore) {
            [encore setForegroundColor:itemColor()];
            return encore;
        }
    }
    NSString *symbol = [name hasPrefix:@"sf:"] ? [name substringFromIndex:3] : name;
    UIImage *image = [UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19 weight:UIImageSymbolWeightSemibold]];
    UIImageView *fallback = [[UIImageView alloc] initWithImage:image ?: [UIImage systemImageNamed:@"star.fill"]];
    fallback.tintColor = itemColor();
    fallback.contentMode = UIViewContentModeCenter;
    return fallback;
}

@interface SGRTabItemView : UIControl
@property (nonatomic, copy) NSString *uri;
- (instancetype)initWithEntry:(NSDictionary *)entry;
- (void)applyEntry:(NSDictionary *)entry;
@end

@implementation SGRTabItemView {
    NSString *_iconName;
    UIView *_icon;
    UILabel *_title;
}

- (instancetype)initWithEntry:(NSDictionary *)entry {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    _title = [UILabel new];
    _title.textAlignment = NSTextAlignmentCenter;
    _title.textColor = itemColor();
    [self addSubview:_title];
    [self applyEntry:entry];
    [self addTarget:self action:@selector(open) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (void)applyEntry:(NSDictionary *)entry {
    self.uri = entry[SGRNavbarURI];
    _title.text = entry[SGRNavbarTitle];
    NSString *name = entry[SGRNavbarIcon] ?: @"star";
    if ([name isEqualToString:_iconName]) return;
    [_icon removeFromSuperview];
    _iconName = [name copy];
    _icon = iconView(name);
    // Encore's views lay themselves out from constraints; this one is placed by frame.
    _icon.translatesAutoresizingMaskIntoConstraints = YES;
    [self addSubview:_icon];
}

// Both boxes come off a neighbour, so whatever Spotify does to the row's line-up is copied rather than
// guessed at; only the horizontal centring is the item's own.
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width;
    // The glass bar of TabBar.x draws the names; the hidden row keeps its icons for the glyphs.
    _title.hidden = YES;
    _title.font = sg_tabFont ?: [UIFont systemFontOfSize:10];
    _title.frame = CGRectMake(0, CGRectGetMinY(sg_labelBox), width, CGRectGetHeight(sg_labelBox));
    _icon.frame = CGRectMake((width - CGRectGetWidth(sg_iconBox)) / 2, CGRectGetMinY(sg_iconBox),
                             CGRectGetWidth(sg_iconBox), CGRectGetHeight(sg_iconBox));
}

// A row that splits its width evenly ignores this, but one that sizes itself to its content would
// otherwise have nothing to go on for an item of ours.
- (CGSize)intrinsicContentSize {
    return CGSizeMake(kIconSize * 2, kLabelTop + kLabelHeight);
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    UIColor *color = selected ? UIColor.whiteColor : itemColor();
    _title.textColor = color;
    _icon.tintColor = color;
    if ([_icon respondsToSelector:@selector(setForegroundColor:)]) [(SPTEncoreIconView *)_icon setForegroundColor:color];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.5 : 1;
}

// Through the app's own link dispatcher (Shared/Navigation/Links.h). What the dispatcher makes of the
// URI goes to the log first, so a tab that ends in Spotify's "Couldn't open link" says why.
- (void)open {
    NSURL *url = SGRNavbarTabURL(self.uri);
    NSString *via = nil;
    SGLinkRoute route = SGSpotifyURIRoute(url, &via);
    SGLog(@"navbar: open %@ -> %@", url.absoluteString ?: self.uri,
          route == SGLinkRouteOpens ? via : route == SGLinkRouteNone ? @"no handler" : @"unknown");
    sg_openingCustom = YES;
    BOOL opened = SGOpenSpotifyURI(url);
    if (opened) { SGRNavbarSelectItem(self); SGRRefreshTabBar(); }
    else SGLog(@"navbar: cannot open %@, dispatcher %@", self.uri, SGLinkDispatcher());
    dispatch_async(dispatch_get_main_queue(), ^{ sg_openingCustom = NO; });
}

@end

BOOL SGRNavbarCustomSelected(UIView *item) { return item == sg_selectedCustom && sg_selectedCustom.selected; }
void SGRNavbarSelectItem(UIView *item) {
    sg_selectedCustom.selected = NO;
    sg_selectedCustom = [item isKindOfClass:SGRTabItemView.class] ? (UIControl *)item : nil;
    sg_selectedCustom.selected = YES;
    SGForEachView(sg_row, ^(UIView *view) {
        if (![view isKindOfClass:UILabel.class]) return;
        for (UIView *owner = view.superview; owner && owner != sg_row; owner = owner.superview) if ([owner isKindOfClass:SGRTabItemView.class]) return;
        UILabel *label = (UILabel *)view;
        UIColor *original = objc_getAssociatedObject(label, &kStockColorKey);
        if (sg_selectedCustom) {
            if (!original) objc_setAssociatedObject(label, &kStockColorKey, label.textColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            label.textColor = itemColor();
        } else if (original) {
            label.textColor = original;
            objc_setAssociatedObject(label, &kStockColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    });
}

@interface SGRStockTabTap : UITapGestureRecognizer <UIGestureRecognizerDelegate>
@end
@implementation SGRStockTabTap
- (instancetype)init {
    if (!(self = [super initWithTarget:self action:@selector(tapped)])) return nil;
    self.cancelsTouchesInView = NO;
    self.delegate = self;
    return self;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return YES; }
- (void)tapped { SGRNavbarSelectItem(self.view); SGRRefreshTabBar(); }
@end

#pragma mark - composition

// Spotify's items are told apart by the label under the icon: it survives the element views being
// rebuilt, and it is the name the Navbar page lists them under.
static NSString *stockID(UIView *item) {
    __block NSString *text = nil;
    SGForEachView(item, ^(UIView *v) {
        if (!text && [v isKindOfClass:UILabel.class] && ((UILabel *)v).text.length) text = ((UILabel *)v).text;
    });
    return text ?: NSStringFromClass(item.class);
}

static void measureItem(UIView *item) {
    __block UIView *icon = nil, *label = nil;
    SGForEachView(item, ^(UIView *v) {
        if (!icon && [NSStringFromClass(v.class) containsString:@"IconView"] && v.bounds.size.width > 1) icon = v;
        if (!label && [v isKindOfClass:UILabel.class] && ((UILabel *)v).text.length) label = v;
    });
    if (icon) sg_iconBox = SGFrameIn(icon, item);
    if (!label) return;
    sg_labelBox = SGFrameIn(label, item);
    if (!sg_tabFont) sg_tabFont = ((UILabel *)label).font;
}

static NSMutableDictionary<NSString *, SGRTabItemView *> *customItems(UIStackView *stack) {
    NSMutableDictionary *items = objc_getAssociatedObject(stack, &kCustomKey);
    if (!items) {
        items = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(stack, &kCustomKey, items, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return items;
}

void SGRComposeTabBar(UIView *tabBar) {
    UIStackView *stack = SGRowIn(tabBar);
    if (!stack) return;
    sg_navbarRoot = tabBar;

    NSMutableDictionary<NSString *, UIView *> *stockViews = [NSMutableDictionary dictionary];
    for (UIView *item in stack.arrangedSubviews) {
        if ([item isKindOfClass:SGRTabItemView.class]) continue;
        BOOL watched = NO;
        for (UIGestureRecognizer *gesture in item.gestureRecognizers) if ([gesture isKindOfClass:SGRStockTabTap.class]) watched = YES;
        if (!watched) [item addGestureRecognizer:[SGRStockTabTap new]];
        NSString *ident = stockID(item);
        if (stockViews[ident]) continue;
        stockViews[ident] = item;
        measureItem(item);
        if (!sg_stockOrder) sg_stockOrder = [NSMutableArray array];
        if (![sg_stockOrder containsObject:ident]) [sg_stockOrder addObject:ident];
    }
    if (sg_stockOrder && ![sg_stockOrder isEqualToArray:SGRNavbarStock()]) SGRSetNavbarStock(sg_stockOrder);

    NSMutableDictionary<NSString *, SGRTabItemView *> *custom = customItems(stack);
    NSMutableArray<UIView *> *wanted = [NSMutableArray array];
    NSMutableSet<NSString *> *placed = [NSMutableSet set];
    NSMutableSet<NSString *> *keep = [NSMutableSet set];

    if (SGEnabled(SGRKeyNavbar)) {
        for (NSDictionary *entry in SGRNavbarLayout()) {
            NSString *ident = entry[SGRNavbarID];
            if (![ident isKindOfClass:NSString.class] || [placed containsObject:ident]) continue;
            [placed addObject:ident];
            BOOL hidden = [entry[SGRNavbarHidden] boolValue];
            if (entry[SGRNavbarURI]) {
                if (hidden) continue;
                SGRTabItemView *item = custom[ident];
                if (item) [item applyEntry:entry];
                else custom[ident] = item = [[SGRTabItemView alloc] initWithEntry:entry];
                [keep addObject:ident];
                [wanted addObject:item];
            } else if (stockViews[ident]) {
                stockViews[ident].hidden = hidden;
                [wanted addObject:stockViews[ident]];
            }
        }
    }
    // Tabs of Spotify's the list does not name — or named before Spotify had built them — keep
    // Spotify's own place, at the end, shown.
    for (NSString *ident in sg_stockOrder) {
        UIView *item = stockViews[ident];
        if (!item || [wanted containsObject:item]) continue;
        item.hidden = NO;
        [wanted addObject:item];
    }
    for (NSString *ident in custom.allKeys) {
        if ([keep containsObject:ident]) continue;
        [custom[ident] removeFromSuperview];
        [custom removeObjectForKey:ident];
    }

    // A bar with nothing on it would strand whoever emptied it, so the last word is Spotify's.
    BOOL empty = YES;
    for (UIView *item in wanted) if (!item.hidden) empty = NO;
    if (empty) for (UIView *item in wanted) item.hidden = NO;

    // Items of the mod's own join the stack at the end, where they are past whatever Spotify
    // counts, and Spotify's own keep the places it gave them.
    for (UIView *item in wanted) {
        if ([item isKindOfClass:SGRTabItemView.class] && item.superview != stack) [stack addArrangedSubview:item];
    }
    NSMutableArray<UIView *> *order = [NSMutableArray array];
    for (UIView *item in wanted) if (!item.hidden && item.superview == stack) [order addObject:item];
    sg_row = stack;
    if (![order isEqualToArray:objc_getAssociatedObject(stack, &kOrderKey)]) {
        objc_setAssociatedObject(stack, &kOrderKey, order, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [stack setNeedsLayout];
    }
}

// Spotify placed the icon and the label for the width it measured (trees/test5.txt: x 28 in a
// 134pt slot, the centre of the 80pt it had with five tabs) and lays the item out no further
// once the slot changes. Assigning the centres back sends them through the hooks below.
static void centreContents(UIView *item) {
    SGForEachView(item, ^(UIView *v) {
        if ([v isKindOfClass:%c(SPTEncoreIconView)] || [v isKindOfClass:%c(SPTEncoreLabel)]) v.center = v.center;
    });
}

// Equal slots across the bar, in the order composed above. The frames go on after the stack's
// own pass, so Spotify's own widths never decide whether a fifth item fits.
static void placeRow(UIStackView *stack) {
    NSArray<UIView *> *order = objc_getAssociatedObject(stack, &kOrderKey);
    UIView *bar = sg_navbarRoot;
    if (!order.count || !bar) return;
    CGFloat width = bar.bounds.size.width / order.count;
    CGFloat height = stack.bounds.size.height;
    [order enumerateObjectsUsingBlock:^(UIView *item, NSUInteger i, BOOL *stop) {
        CGFloat x = [bar convertPoint:CGPointMake(i * width, 0) toView:stack].x;
        CGRect frame = CGRectMake(x, 0, width, height);
        if (!CGAffineTransformIsIdentity(item.transform)) item.transform = CGAffineTransformIdentity;
        if (!CGRectEqualToRect(item.frame, frame)) item.frame = frame;
        centreContents(item);
    }];
}

%hook UIStackView
- (void)layoutSubviews {
    %orig;
    if ((UIStackView *)self == sg_row) placeRow((UIStackView *)self);
}
%end

// Spotify's element layout places the icon and the label from the width it measured, not from
// the slot above (trees/test5.txt: x 38 in a 134pt element in a 126pt slot), and a view placed by
// its parent gets no layout pass of its own. So the placement itself is bent: on the bar, whatever
// x Spotify sets, the view lands centred on its slot.
static CGFloat slotCentreX(UIView *view) {
    UIStackView *row = sg_row;
    if (!row) return NAN;
    UIView *slot = nil;
    for (UIView *v = view; v.superview; v = v.superview) if (v.superview == row) { slot = v; break; }
    if (!slot) return NAN;
    return [slot convertPoint:CGPointMake(CGRectGetMidX(slot.bounds), 0) toView:view.superview].x;
}

%hook SPTEncoreIconView
- (void)setFrame:(CGRect)frame {
    CGFloat centre = slotCentreX((UIView *)self);
    if (!isnan(centre)) frame.origin.x = centre - frame.size.width / 2;
    %orig(frame);
}
- (void)setCenter:(CGPoint)center {
    CGFloat centre = slotCentreX((UIView *)self);
    if (!isnan(centre)) center.x = centre;
    %orig(center);
}
%end

%hook SPTEncoreLabel
- (void)setFrame:(CGRect)frame {
    CGFloat centre = slotCentreX((UIView *)self);
    if (!isnan(centre)) frame.origin.x = centre - frame.size.width / 2;
    %orig(frame);
}
- (void)setCenter:(CGPoint)center {
    CGFloat centre = slotCentreX((UIView *)self);
    if (!isnan(centre)) center.x = centre;
    %orig(center);
}
%end

void SGRRefreshTabBar(void) {
    [sg_navbarRoot setNeedsLayout];
}

// What the row settled on, logged whenever it changes: `make log` then says whether the items fit,
// what is holding their width, and in what order the bar ended up.
void SGRLogTabBarRow(UIView *tabBar) {
    UIStackView *stack = SGRowIn(tabBar);
    if (!stack) return;
    NSMutableArray *signature = [NSMutableArray arrayWithObjects:NSStringFromCGRect(tabBar.frame), NSStringFromCGRect(stack.frame), nil];
    for (UIView *item in stack.arrangedSubviews) [signature addObject:@[[NSValue valueWithNonretainedObject:item], NSStringFromCGRect(item.frame), @(item.hidden)]];
    static NSArray *previous;
    if ([previous isEqualToArray:signature]) return;
    previous = [signature copy];
    NSMutableString *out = [NSMutableString stringWithFormat:@"row in %@ %@, icon %@ label %@, stack %@ axis %ld dist %ld align %ld spacing %.1f autolayout %d",
                            NSStringFromClass(tabBar.class), NSStringFromCGRect(tabBar.frame),
                            NSStringFromCGRect(sg_iconBox), NSStringFromCGRect(sg_labelBox), NSStringFromCGRect(stack.frame),
                            (long)stack.axis, (long)stack.distribution, (long)stack.alignment, stack.spacing,
                            !stack.translatesAutoresizingMaskIntoConstraints];
    NSUInteger index = 0;
    for (UIView *item in stack.arrangedSubviews) {
        [out appendFormat:@"\n  %lu %@ %@%@ autolayout %d", (unsigned long)index++, NSStringFromClass(item.class),
             NSStringFromCGRect(item.frame), item.hidden ? @" hidden" : @"",
             !item.translatesAutoresizingMaskIntoConstraints];
        for (NSLayoutConstraint *c in item.constraints) {
            if (c.firstAttribute == NSLayoutAttributeWidth || c.secondAttribute == NSLayoutAttributeWidth) [out appendFormat:@"\n    %@", c];
        }
    }
    for (NSLayoutConstraint *c in stack.constraints) [out appendFormat:@"\n  own %@", c];
    for (NSLayoutConstraint *c in stack.superview.constraints) {
        if (c.firstItem == stack || c.secondItem == stack) [out appendFormat:@"\n  held %@", c];
    }
    static NSString *last;
    if ([out isEqualToString:last]) return;
    last = [out copy];
    SGLogLong(@"navbar", out);
}

// Whether Spotify reads its own item list through this ObjC bridge decides whether the bar can be
// composed at the model level, where the order, the taps and the widths would all follow by
// themselves, instead of by moving views about. Silence in the log says it cannot.
%hook _TtC28NavigationUI_TabBarItemsImpl29TabBarItemsNavigationListImpl
- (NSArray *)items {
    NSArray *items = %orig;
    NSMutableString *out = [NSMutableString stringWithFormat:@"list read, %lu items", (unsigned long)items.count];
    for (id item in items) [out appendFormat:@"\n  %@ · %@", [item valueForKey:@"title"], [item valueForKey:@"viewURI"]];
    static NSString *last;
    if (![out isEqualToString:last]) {
        last = [out copy];
        SGLogLong(@"navbar", out);
    }
    return items;
}
%end

// Public navigation entry points clear a custom selection when another destination takes over.
%hook UINavigationController
- (void)pushViewController:(UIViewController *)controller animated:(BOOL)animated {
    if (sg_selectedCustom && !sg_openingCustom) SGRNavbarSelectItem(nil);
    %orig;
}
- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (sg_selectedCustom && !sg_openingCustom) SGRNavbarSelectItem(nil);
    return %orig;
}
- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated {
    if (sg_selectedCustom && !sg_openingCustom) SGRNavbarSelectItem(nil);
    return %orig;
}
- (void)setViewControllers:(NSArray *)controllers animated:(BOOL)animated {
    if (sg_selectedCustom && !sg_openingCustom) SGRNavbarSelectItem(nil);
    %orig;
}
%end

%hook _TtC23NavigationUI_TabBarImpl19TabBarContainerImpl
- (void)setSelectedViewController:(UIViewController *)controller {
    if (sg_selectedCustom && !sg_openingCustom) SGRNavbarSelectItem(nil);
    %orig;
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[
        @"SPTEncoreIcon",
        @"SPTEncoreIconView",
        @"SPTEncoreLabel",
        @"_TtC23NavigationUI_TabBarImpl19TabBarContainerImpl",
        @"_TtC28NavigationUI_TabBarItemsImpl29TabBarItemsNavigationListImpl",
    ]);
}
