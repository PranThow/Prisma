#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"
#import "About.h"

@interface SGAppIconsPage : SGPage
@end

@implementation SGAppIconsPage {
    BOOL _changing;
    UIView *_note;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"App icon";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _note = SGNote(@"Choose a Prisma eclipse icon for your Home Screen. Changes apply immediately.");
    self.tableView.tableFooterView = _note;
    self.tableView.rowHeight = 64;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    SGFitNote(self.tableView, _note, 16, 24);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    SGInsetForBars(self.tableView);
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 4; }

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    NSArray *names = @[@"Default", @"Violet", @"Emerald", @"Pearl"];
    NSArray *keys = @[@"", @"PrismaViolet", @"PrismaEmerald", @"PrismaPearl"];
    UITableViewCell *cell = SGDequeueCell(table, @"icon");
    SGFillCell(cell, names[path.row], nil, nil, nil);
    NSString *key = keys[path.row];
    UIImage *image = nil;
    if (key.length) image = [UIImage imageNamed:key];
    else {
        NSDictionary *group = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleIcons"];
        NSString *primary = [group[@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"] lastObject];
        if (primary) image = [UIImage imageNamed:primary];
    }
    if (image) {
        UIImage *preview = image;
        image = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(44, 44)] imageWithActions:^(UIGraphicsImageRendererContext *context) {
            [preview drawInRect:CGRectMake(0, 0, 44, 44)];
        }];
    }
    cell.imageView.image = image ?: [UIImage systemImageNamed:@"app"];
    cell.imageView.layer.cornerRadius = 10;
    cell.imageView.clipsToBounds = YES;
    cell.accessoryType = [key isEqualToString:UIApplication.sharedApplication.alternateIconName ?: @""] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.accessibilityLabel = [names[path.row] stringByAppendingString:@" app icon"];
    cell.accessibilityTraits = UIAccessibilityTraitButton | (cell.accessoryType == UITableViewCellAccessoryCheckmark ? UIAccessibilityTraitSelected : 0);
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (_changing) return;
    NSString *key = @[@"", @"PrismaViolet", @"PrismaEmerald", @"PrismaPearl"][path.row];
    if ([key isEqualToString:UIApplication.sharedApplication.alternateIconName ?: @""]) return;
    _changing = YES;
    [UIApplication.sharedApplication setAlternateIconName:key.length ? key : nil completionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_changing = NO;
            self->_note = SGNote(error ? [@"The icon could not be changed. " stringByAppendingString:error.localizedDescription] :
                @"Choose a Prisma eclipse icon for your Home Screen. Changes apply immediately.");
            self.tableView.tableFooterView = self->_note;
            if (error) {
                UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, error.localizedDescription);
            }
            [self.tableView reloadData];
            [self.view setNeedsLayout];
        });
    }];
}
@end

SGModRow *SGAppIconRow(void) {
    if (@available(iOS 26.0, *)) {
        NSDictionary *icons = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleIcons"];
        if (UIApplication.sharedApplication.supportsAlternateIcons && icons[@"CFBundleAlternateIcons"][@"PrismaViolet"]) {
            return SGWithSymbol(SGPageRow(@"App icon", ^UIViewController *{ return [SGAppIconsPage new]; }), @"app");
        }
    }
    return SGWithSymbol(SGStatRow(@"App icon", ^NSString *{ return @"Needs iOS 26 and a Prisma IPA"; }), @"app");
}
