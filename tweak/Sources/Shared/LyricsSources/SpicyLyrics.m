// Independent client for https://developers.spicylyrics.org/docs/reference/get.lyrics (2026-10-07).
// Only user supplied publishable keys; native clients require No origin header enabled in the dashboard.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "LyricsSources.h"
#import <math.h>

static NSString *const kKey = @"spotifyglass.spicyPublishableKey";
static NSString *sg_status = @"Add a publishable key";
static NSTimeInterval sg_retryAfter;
static NSUInteger sg_losses;
static BOOL sg_rejected;

static BOOL token(NSString *value, NSString *prefix, NSUInteger maximum) {
    if (![value isKindOfClass:NSString.class] || ![value hasPrefix:prefix] || value.length <= prefix.length || value.length > maximum) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"];
    return [value rangeOfCharacterFromSet:allowed.invertedSet].location == NSNotFound;
}
static BOOL milliseconds(id value, NSInteger *result) {
    if (![value isKindOfClass:NSNumber.class]) return NO;
    double seconds = [value doubleValue];
    if (!isfinite(seconds) || seconds < 0 || seconds > 86400) return NO;
    *result = (NSInteger)llround(seconds * 1000);
    return YES;
}
static NSString *string(id value) { return [value isKindOfClass:NSString.class] ? value : nil; }
static NSURL *creditURL(id value) {
    NSURL *url = [NSURL URLWithString:string(value) ?: @""];
    return [url.scheme.lowercaseString isEqualToString:@"https"] && url.host.length && !url.user && !url.password ? url : nil;
}
static SGKaraokeLine *vocal(id object) {
    if (![object isKindOfClass:NSDictionary.class]) return nil;
    NSArray *syllables = object[@"Syllables"];
    if (![syllables isKindOfClass:NSArray.class] || !syllables.count || syllables.count > 4096) return nil;
    SGKaraokeLine *line = [SGKaraokeLine new];
    NSInteger lineStart, lineEnd;
    if (!milliseconds(object[@"StartTime"], &lineStart)) return nil;
    if (!milliseconds(object[@"EndTime"], &lineEnd) || lineEnd < lineStart) return nil;
    line.start = lineStart; line.end = lineEnd;
    NSMutableArray *words = [NSMutableArray array], *pronounced = [NSMutableArray array];
    BOOL joined = NO;
    for (id item in syllables) {
        if (![item isKindOfClass:NSDictionary.class]) return nil;
        NSString *text = string(item[@"Text"]);
        NSInteger start, end;
        if (!text.length || text.length > 4096 || !milliseconds(item[@"StartTime"], &start) || !milliseconds(item[@"EndTime"], &end) || end < start || start < line.start || end > line.end) return nil;
        SGKaraokeWord *word = [SGKaraokeWord new];
        word.text = text; word.start = start; word.end = end; word.joined = joined;
        [words addObject:word];
        NSString *latin = string(item[@"TransliteratedText"]);
        SGKaraokeWord *pronunciation = [SGKaraokeWord new];
        pronunciation.text = latin.length ? latin : text;
        pronunciation.start = start; pronunciation.end = end; pronunciation.joined = joined;
        [pronounced addObject:pronunciation];
        joined = [item[@"IsPartOfWord"] isKindOfClass:NSNumber.class] && [item[@"IsPartOfWord"] boolValue];
    }
    line.words = words;
    line.timing = SGKaraokeTimingWords;
    line.translation = string(object[@"TranslatedText"]);
    SGKaraokeLine *pronunciation = [SGKaraokeLine new];
    pronunciation.words = pronounced; pronunciation.start = line.start; pronunciation.end = line.end;
    if (![SGKaraokeLineText(line) isEqualToString:SGKaraokeLineText(pronunciation)]) line.pronunciation = pronunciation;
    return line;
}
SGLyricsResult *SGSpicyLyricsParse(id root, NSString *trackID) {
    if (![root isKindOfClass:NSDictionary.class]) return nil;
    id body = root[@"Body"];
    if (![body isKindOfClass:NSDictionary.class] || ![string(body[@"id"]) isEqualToString:trackID]) return nil;
    // The published reference defines the Syllable payload. Reject other shapes until documented.
    if (![string(body[@"Type"]) isEqualToString:@"Syllable"]) return nil;
    NSArray *content = body[@"Content"];
    if (![content isKindOfClass:NSArray.class] || !content.count || content.count > 4096) return nil;
    NSMutableArray *lines = [NSMutableArray array];
    for (id item in content) {
        if (![item isKindOfClass:NSDictionary.class]) return nil;
        if (![string(item[@"Type"]) isEqualToString:@"Vocal"]) continue;
        SGKaraokeLine *line = vocal(item[@"Lead"]);
        if (!line) return nil;
        line.align = [item[@"OppositeAligned"] isKindOfClass:NSNumber.class] && [item[@"OppositeAligned"] boolValue] ? SGKaraokeAlignTrailing : SGKaraokeAlignLeading;
        NSArray *background = item[@"Background"];
        if (background && ![background isKindOfClass:NSArray.class]) return nil;
        if ([background isKindOfClass:NSArray.class] && background.count) {
            // Prisma supports one backing voice; reject loss of additional voices rather than flatten timings.
            if (background.count != 1 || !(line.backing = vocal(background.firstObject))) return nil;
        }
        [lines addObject:line];
    }
    if (!lines.count) return nil;
    [lines sortUsingComparator:^NSComparisonResult(SGKaraokeLine *a, SGKaraokeLine *b) {
        return a.start < b.start ? NSOrderedAscending : a.start > b.start ? NSOrderedDescending : NSOrderedSame;
    }];
    NSString *source = string(body[@"source"]);
    NSString *name = [@{@"spicy_lyrics": @"Spicy Lyrics", @"apple_music": @"Apple Music", @"spotify": @"Spotify"} objectForKey:source ?: @""] ?: @"Unknown source";
    NSMutableAttributedString *credit = [[NSMutableAttributedString alloc] initWithString:name];
    NSString *catalogue = [source isEqualToString:@"spicy_lyrics"] ? @"https://spicylyrics.org"
        : [source isEqualToString:@"apple_music"] ? @"https://music.apple.com"
        : [source isEqualToString:@"spotify"] ? [@"https://open.spotify.com/track/" stringByAppendingString:trackID] : nil;
    if (catalogue) [credit addAttribute:NSLinkAttributeName value:[NSURL URLWithString:catalogue] range:NSMakeRange(0, credit.length)];
    if ([source isEqualToString:@"spicy_lyrics"]) {
        id attribution = body[@"UploadAttribution"];
        if (![attribution isKindOfClass:NSDictionary.class]) return nil;
        for (NSString *role in @[@"Uploader", @"Maker"]) {
            id person = attribution[role];
            if (!person && [role isEqualToString:@"Maker"]) continue;
            if (![person isKindOfClass:NSDictionary.class]) return nil;
            NSString *username = string(person[@"username"]);
            NSURL *url = creditURL(person[@"url"]);
            if (!username.length || username.length > 256 || !url) return nil;
            [credit appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" · %@: ", role]]];
            [credit appendAttributedString:[[NSAttributedString alloc] initWithString:username attributes:@{NSLinkAttributeName: url}]];
        }
    }
    SGLyricsResult *result = [SGLyricsResult new];
    result.provider = name; result.attribution = credit;
    for (SGKaraokeLine *line in lines) line.sourceAttribution = credit;
    result.synced = YES; result.wordTimed = YES; result.karaokeLines = lines;
    NSArray *starts, *texts;
    SGLyricsPageLines(lines, &starts, &texts);
    result.starts = starts; result.texts = texts;
    return result;
}

@interface SGSpicyRequest : NSObject <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableData *body;
@property (nonatomic, copy) void (^done)(NSData *, NSHTTPURLResponse *, NSError *);
@end
@implementation SGSpicyRequest
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))handler { handler(nil); }
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))handler {
    handler(response.expectedContentLength > 2 * 1024 * 1024 ? NSURLSessionResponseCancel : NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if (self.body.length + data.length > 2 * 1024 * 1024) { [task cancel]; return; }
    [self.body appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSData *body = self.body;
    NSHTTPURLResponse *response = [task.response isKindOfClass:NSHTTPURLResponse.class] ? (id)task.response : nil;
    void (^done)(NSData *, NSHTTPURLResponse *, NSError *) = self.done;
    self.done = nil;
    [session finishTasksAndInvalidate];
    self.session = nil;
    dispatch_async(dispatch_get_main_queue(), ^{ done(body, response, error); });
}
@end

SGLyricsAsk SGSpicyLyricsAsk = ^(SGLyricsQuery *query, void (^done)(SGLyricsResult *)) {
    NSString *key = [NSUserDefaults.standardUserDefaults stringForKey:kKey];
    NSCharacterSet *base62 = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"];
    if (!token(key, @"sl_pk_", 512) || query.trackID.length != 22 || [query.trackID rangeOfCharacterFromSet:base62.invertedSet].location != NSNotFound || sg_rejected) { done(nil); return; }
    if (NSDate.date.timeIntervalSince1970 < sg_retryAfter) {
        SGLyricsNoteReply(nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]);
        done(nil); return;
    }
    NSURL *url = [NSURL URLWithString:[@"https://api.spicylyrics.org/v1/lyrics/" stringByAppendingString:query.trackID]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:6];
    [request setValue:[@"Bearer " stringByAppendingString:key] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    SGSpicyRequest *fetch = [SGSpicyRequest new];
    fetch.body = [NSMutableData data];
    fetch.done = ^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (![key isEqualToString:[NSUserDefaults.standardUserDefaults stringForKey:kKey]]) { done(nil); return; }
        SGLyricsNoteReply(response, error);
        NSInteger status = response.statusCode;
        if (status == 401 || status == 403) {
            sg_rejected = YES; sg_status = @"Key rejected; check native-client access or replace key";
        } else if (error || status == 429 || status >= 500) {
            sg_losses = MIN(sg_losses + 1, 6u);
            NSTimeInterval wait = MIN(10 * pow(2, sg_losses - 1), 600);
            double retry = [response.allHeaderFields[@"Retry-After"] doubleValue];
            if (isfinite(retry) && retry > 0) wait = MIN(MAX(wait, retry), 86400);
            sg_retryAfter = NSDate.date.timeIntervalSince1970 + wait;
            sg_status = @"Service unavailable; retrying later";
        } else if (status == 200 || status == 404) { sg_losses = 0; sg_status = @"Key accepted"; }
        id root = status == 200 && !error ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        done(SGSpicyLyricsParse(root, query.trackID));
    };
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.HTTPMaximumConnectionsPerHost = 2;
    configuration.timeoutIntervalForRequest = 6;
    configuration.timeoutIntervalForResource = 8;
    configuration.URLCache = nil;
    fetch.session = [NSURLSession sessionWithConfiguration:configuration delegate:fetch delegateQueue:nil];
    [[fetch.session dataTaskWithRequest:request] resume];
};

UIViewController *SGSpicyLyricsSettingsPage(void) {
    SGModRow *key = SGActionRow(@"Publishable key", @"sl_pk_ keys only; restart after changing", ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Spicy Lyrics key" message:@"Use your own publishable key with No origin header enabled for native clients. Secret keys are rejected." preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder = @"sl_pk_…"; field.autocorrectionType = UITextAutocorrectionTypeNo;
            field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *value = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (!value.length) [NSUserDefaults.standardUserDefaults removeObjectForKey:kKey];
            else if (token(value, @"sl_pk_", 512)) [NSUserDefaults.standardUserDefaults setObject:value forKey:kKey];
            else { sg_status = @"Invalid publishable key"; return; }
            sg_rejected = NO; sg_retryAfter = 0; sg_losses = 0;
            sg_status = value.length ? @"Saved; checked on next lyrics request" : @"Add a publishable key";
        }]];
        [SGTopController() presentViewController:alert animated:YES completion:nil];
    });
    return [[SGModPage alloc] initWithTitle:@"Spicy Lyrics" intro:@"Enable Spicy Lyrics in Sources after adding a key. The configured order controls fallback. Cached replies stay in memory for this launch." sections:@[
        SGSection(@"Access", @[key, SGStatRow(@"Status", ^NSString *{ return sg_status; }),
            SGLinkRow(@"Developer dashboard", nil, @"https://developers.spicylyrics.org/dashboard"),
            SGLinkRow(@"Client key setup", nil, @"https://developers.spicylyrics.org/docs/keys")]),
    ] footer:@"Prisma is independent of Spicy Lyrics. Community credits remain visible wherever these lyrics are displayed."];
}
