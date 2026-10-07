#import "Core/SGCore.h"
#import "Settings/SGPage.h"
#import "Navbar.h"
#import "Shared/Navigation/Links.h"
#import "Headers/SPTEncoreIconView.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <stdlib.h>

@interface SGTabEditor : SGPage <UISearchResultsUpdating>
@property (nonatomic, copy) NSDictionary *initialEntry;
@property (nonatomic, copy) void (^saved)(NSDictionary *entry);
@end
@implementation SGTabEditor {
    UITextField *_name, *_link;
    NSArray<NSString *> *_icons, *_filtered;
    NSString *_icon;
    UISearchController *_search;
}
- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Add a Tab";
    _icon = @"star";
    NSMutableArray *icons = [NSMutableArray array];
    // Spotify 9.1.78's supplied SpotifyShared binary: 538 own zero-argument glyph factories.
    unsigned count = 0;
    Method *methods = class_copyMethodList(object_getClass(NSClassFromString(@"SPTEncoreIcon")), &count);
    for (unsigned i = 0; i < count; i++) {
        const char *type = method_getTypeEncoding(methods[i]);
        if (method_getNumberOfArguments(methods[i]) == 2 && type && type[0] == '@') [icons addObject:NSStringFromSelector(method_getName(methods[i]))];
    }
    free(methods);
    [icons sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    // Independently curated platform names, checked on this OS before offering them.
    for (NSString *name in [@"house magnifyingglass books.vertical heart star music.note music.note.list person person.2 person.3 square.stack play.circle pause.circle radio antenna.radiowaves.left.and.right headphones speaker.wave.2 mic waveform guitar pianokeys drum film tv desktopcomputer laptopcomputer iphone ipad applewatch airpods bolt flame sparkles moon sun.max cloud leaf globe map pin location calendar clock timer alarm bell bookmark flag tag folder tray archivebox doc link paperclip photo camera paintpalette wand.and.stars slider.horizontal.3 gearshape wrench scissors pencil square.and.pencil checkmark.circle plus.circle arrow.down.circle arrow.up.circle arrow.left arrow.right shuffle repeat ellipsis circle grid note.text list.bullet chart.bar crown gift gamecontroller dumbbell figure.walk bicycle car airplane ferry" componentsSeparatedByString:@" "]) {
        if ([UIImage systemImageNamed:name]) [icons addObject:[@"sf:" stringByAppendingString:name]];
    }
    _icons = _filtered = icons;
    return self;
}
- (UITextField *)field:(NSString *)placeholder {
    UITextField *field = [UITextField new];
    field.placeholder = placeholder;
    field.textColor = UIColor.whiteColor;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    return field;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    _name = [self field:@"Name"];
    _link = [self field:@"Spotify share link or spotify: URI"];
    _link.keyboardType = UIKeyboardTypeURL;
    _name.text = self.initialEntry[SGNavbarTitle];
    _link.text = self.initialEntry[SGNavbarURI];
    _icon = self.initialEntry[SGNavbarIcon] ?: _icon;
    _search = [[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater = self;
    _search.obscuresBackgroundDuringPresentation = NO;
    _search.searchBar.placeholder = @"Search Spotify glyphs and SF Symbols";
    self.navigationItem.searchController = _search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Add" style:UIBarButtonItemStyleDone target:self action:@selector(saveTab)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
}
- (void)cancel { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)updateSearchResultsForSearchController:(UISearchController *)search {
    NSString *query = search.searchBar.text ?: @"";
    _filtered = query.length ? [_icons filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *name, NSDictionary *bindings) { return [name rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound; }]] : _icons;
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 2; }
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return section ? _filtered.count : 3; }
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section { return section ? @"Icon" : @"Tab"; }
- (UIView *)preview:(NSString *)name {
    if ([name hasPrefix:@"sf:"]) {
        UIImageView *view = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:[name substringFromIndex:3]]];
        view.contentMode = UIViewContentModeScaleAspectFit;
        view.tintColor = UIColor.whiteColor;
        view.frame = CGRectMake(0, 0, 24, 24);
        return view;
    }
    Class icon = NSClassFromString(@"SPTEncoreIcon"), viewClass = NSClassFromString(@"SPTEncoreIconView");
    SEL selector = NSSelectorFromString(name);
    if (![icon respondsToSelector:selector] || !viewClass) return nil;
    id glyph = ((id (*)(id, SEL))objc_msgSend)(icon, selector);
    SPTEncoreIconView *view = glyph ? [[viewClass alloc] initWithIcon:glyph] : nil;
    view.frame = CGRectMake(0, 0, 24, 24);
    [view setForegroundColor:UIColor.whiteColor];
    return view;
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    cell.textLabel.textColor = UIColor.whiteColor;
    if (!path.section && path.row < 2) {
        UITextField *field = path.row ? _link : _name;
        field.frame = CGRectInset(cell.contentView.bounds, 16, 0);
        field.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:field];
    } else {
        NSString *name = path.section ? _filtered[path.row] : _icon;
        cell.textLabel.text = path.section ? name : @"Selected icon";
        cell.detailTextLabel.text = path.section ? ([name hasPrefix:@"sf:"] ? @"SF Symbol" : @"Spotify glyph") : name;
        cell.detailTextLabel.textColor = UIColor.lightGrayColor;
        cell.accessoryView = [self preview:name];
        cell.accessibilityLabel = [NSString stringWithFormat:@"%@%@", name, [name isEqualToString:_icon] ? @", selected" : @""];
        if ([name isEqualToString:_icon]) cell.textLabel.textColor = SGGreen();
    }
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (!path.section) return;
    _icon = _filtered[path.row];
    [table reloadData];
}
- (void)saveTab {
    NSURL *url = SGSpotifyURIFromText(_link.text);
    NSString *via = nil;
    if (!url || SGSpotifyURIRoute(url, &via) == SGLinkRouteNone) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Can't open that link" message:@"Enter a Spotify share link or URI that Spotify can open." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSString *title = [_name.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (self.saved) self.saved(@{SGNavbarTitle:title.length ? title : url.absoluteString, SGNavbarURI:url.absoluteString, SGNavbarIcon:_icon});
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
