// Drag providers into the order they are asked; the ones below the line are off.
#import "Core/SGCore.h"
#import "Settings/SGPage.h"
#import "Settings/SGPageStyle.h"
#import "AnimatedArtwork.h"
#import "AnimatedArtworkSettings.h"

typedef NS_ENUM(NSInteger, SGArtworkProvidersSection) {
    SGArtworkProvidersSectionOn = 0,
    SGArtworkProvidersSectionOff,
    SGArtworkProvidersSectionCount,
};

@interface SGArtworkProvidersPage : SGPage
@end

@implementation SGArtworkProvidersPage {
    NSMutableArray<NSString *> *_on;    // keys, in the order they are asked
    NSMutableArray<NSString *> *_off;
    UIView *_footer;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Artwork providers";
    return self;
}

- (void)read {
    _on = [SGAnimatedArtworkOrder() mutableCopy];
    _off = [NSMutableArray array];
    for (NSString *key in SGAnimatedArtworkAllProviders()) {
        if (![_on containsObject:key]) [_off addObject:key];
    }
}

- (void)save {
    SGAnimatedArtworkSetOrder(_on);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self read];
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    _footer = SGNote(@"Tap a provider to turn it on or off. Drag enabled providers into the order to try. "
                      "Changes apply after you restart Spotify.");
    self.tableView.tableFooterView = _footer;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    SGFitNote(self.tableView, _footer, 16, 24);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    SGInsetForBars(self.tableView);
}

- (NSMutableArray<NSString *> *)keysIn:(NSInteger)section {
    return section == SGArtworkProvidersSectionOn ? _on : _off;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return SGArtworkProvidersSectionCount;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[self keysIn:section].count;
}

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (section == SGArtworkProvidersSectionOn) return SGSectionHeader(table, _on.count ? @"Asked in this order" : @"None on");
    return _off.count ? SGSectionHeader(table, @"Off") : nil;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    return section == SGArtworkProvidersSectionOn || _off.count ? SGSectionHeaderHeight : CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)table heightForFooterInSection:(NSInteger)section {
    return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = SGDequeueCell(table, @"source");
    NSString *key = [self keysIn:path.section][(NSUInteger)path.row];
    NSString *name = [key isEqualToString:@"spotify"] ? @"Spotify Canvas" : @"Apple Music";
    BOOL on = path.section == SGArtworkProvidersSectionOn;
    // The enabled ones are numbered, so the order reads as an order rather than a list.
    NSString *title = on ? [NSString stringWithFormat:@"%ld. %@", (long)path.row + 1, name] : name;
    SGFillCell(cell, title, nil, on ? nil : SGGrey(), on ? @"checkmark.circle.fill" : @"circle");
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (BOOL)tableView:(UITableView *)table canMoveRowAtIndexPath:(NSIndexPath *)path {
    return path.section == SGArtworkProvidersSectionOn;
}

- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)table editingStyleForRowAtIndexPath:(NSIndexPath *)path {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)table shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)path {
    return NO;
}

// Dragging stays inside the order; a provider is switched on and off by tapping it, not by dropping
// it into the other section, so an order is never lost to a stray drag.
- (NSIndexPath *)tableView:(UITableView *)table targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)from toProposedIndexPath:(NSIndexPath *)to {
    return to.section == SGArtworkProvidersSectionOn ? to : from;
}

- (void)tableView:(UITableView *)table moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSString *key = _on[(NSUInteger)from.row];
    [_on removeObjectAtIndex:(NSUInteger)from.row];
    [_on insertObject:key atIndex:(NSUInteger)to.row];
    [self save];
    [table reloadData];   // the numbers in front of the names have all moved
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    NSString *key = [self keysIn:path.section][(NSUInteger)path.row];
    if (path.section == SGArtworkProvidersSectionOn) {
        [_on removeObject:key];
        // Back to where it sits among the providers that are off, in the order they all come in.
        NSUInteger at = 0;
        for (NSString *provider in SGAnimatedArtworkAllProviders()) {
            if ([provider isEqualToString:key]) break;
            if ([_off containsObject:provider]) at++;
        }
        [_off insertObject:key atIndex:at];
    } else {
        [_off removeObject:key];
        [_on addObject:key];
    }
    [self save];
    [table reloadData];
}

@end

UIViewController *SGAnimatedArtworkProvidersPage(void) {
    return [SGArtworkProvidersPage new];
}
