#import "AppleMusicArtwork.h"
#import <math.h>

static NSError *resolverError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"Prisma.AppleMusicArtwork" code:code
                           userInfo:@{NSLocalizedDescriptionKey:message}];
}
static NSDictionary *jwtPart(NSString *token, NSUInteger index) {
    if (!token.length || token.length > 16384 || [token rangeOfCharacterFromSet:
        [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_."].invertedSet].location != NSNotFound) return nil;
    NSArray *parts = [token componentsSeparatedByString:@"."];
    if (parts.count != 3 || ![parts[0] length] || ![parts[1] length] || ![parts[2] length]) return nil;
    NSString *part = [[parts[index] stringByReplacingOccurrencesOfString:@"-" withString:@"+"]
        stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    while (part.length % 4) part = [part stringByAppendingString:@"="];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:part options:0];
    id root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    return [root isKindOfClass:NSDictionary.class] ? root : nil;
}
static NSTimeInterval tokenExpiry(NSString *token) {
    NSDictionary *header = jwtPart(token,0), *claims = jwtPart(token,1);
    id exp = claims[@"exp"];
    double expiry = [exp isKindOfClass:NSNumber.class] ? [exp doubleValue] : 0;
    return [header[@"alg"] isEqual:@"ES256"] && isfinite(expiry) ? expiry : 0;
}
typedef void (^SGAppleFetch)(NSData *, NSHTTPURLResponse *, NSError *);
@interface SGAppleMusicArtworkResolver () <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDataTask *task;
@property (nonatomic, strong) NSMutableData *body;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSError *failure;
@property (nonatomic, copy) SGAppleFetch fetched;
@property (nonatomic) NSUInteger limit;
@property (nonatomic) NSUInteger generation;
@property (nonatomic, copy) void (^completion)(NSURL *, NSError *);
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, copy) NSString *cacheKey;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic) double ratio;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *configuredToken;
@property (nonatomic) BOOL guest;
@property (nonatomic) BOOL refreshed;
@property (nonatomic) NSTimeInterval blockedUntil;
@end

@implementation SGAppleMusicArtworkResolver
- (void)cancel {
    self.generation++;
    [self.task cancel]; self.task = nil;
    [self.session invalidateAndCancel]; self.session = nil;
    self.fetched = nil; self.completion = nil; self.body = nil;
}
- (void)finish:(NSURL *)clip error:(NSError *)error confirmed:(BOOL)confirmed {
    if (!self.completion) return;
    if (clip || confirmed) {
        [self.cache setObject:@{ @"clip":clip ?: NSNull.null,
            @"until":@([NSDate.date timeIntervalSince1970] + (clip ? 21600 : 3600)) } forKey:self.cacheKey];
    }
    void (^done)(NSURL *, NSError *) = self.completion;
    self.completion = nil;
    done(clip,error);
}
- (void)resolveArtist:(NSString *)artist album:(NSString *)album aspectRatio:(double)ratio
           completion:(void (^)(NSURL *, NSError *))completion {
    NSAssert(NSThread.isMainThread, @"Apple artwork resolution starts on the main queue");
    [self cancel];
    self.completion = completion;
    if (!SGAppleArtworkNormalize(artist).length || !SGAppleArtworkNormalize(album).length ||
        !isfinite(ratio) || ratio < .1 || ratio > 10) {
        [self finish:nil error:resolverError(1,@"Missing artist, album or valid aspect ratio") confirmed:NO]; return;
    }
    self.artist = artist; self.album = album; self.ratio = ratio; self.refreshed = NO;
    id configured = [NSUserDefaults.standardUserDefaults objectForKey:SGKeyAppleMusicDeveloperToken];
    NSString *setting = [configured isKindOfClass:NSString.class] ? configured : @"";
    if (![setting isEqual:self.configuredToken]) {
        self.configuredToken = setting; self.token = nil;
        [self.cache removeAllObjects];
    }
    self.guest = !setting.length;
    if (!self.cache) { self.cache = [NSCache new]; self.cache.countLimit = 128; }
    self.cacheKey = [@[SGAppleArtworkNormalize(artist),SGAppleArtworkNormalize(album),@(ratio)] description];
    NSDictionary *cached = [self.cache objectForKey:self.cacheKey];
    if ([cached[@"until"] doubleValue] > NSDate.date.timeIntervalSince1970) {
        id clip = cached[@"clip"];
        self.completion = nil;
        completion(clip == NSNull.null ? nil : clip,nil); return;
    }
    if (NSDate.date.timeIntervalSince1970 < self.blockedUntil) {
        [self finish:nil error:resolverError(429,@"Apple artwork requests are cooling down") confirmed:NO]; return;
    }
    [self authorize];
}
- (void)fetch:(NSURL *)url authorization:(NSString *)token limit:(NSUInteger)limit
      attempt:(NSUInteger)attempt completion:(SGAppleFetch)completion {
    // This isolated session never reads Spotify headers, cookies, or credential storage.
    if (token && ![@[@"api.music.apple.com",@"amp-api.music.apple.com"] containsObject:url.host]) {
        completion(nil,nil,resolverError(1,@"Authorization destination rejected")); return;
    }
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.HTTPCookieStorage = nil; config.URLCredentialStorage = nil; config.URLCache = nil;
    config.allowsConstrainedNetworkAccess = NO; config.waitsForConnectivity = NO;
    config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 30;
    self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:NSOperationQueue.mainQueue];
    self.limit = limit; self.body = [NSMutableData new]; self.response = nil; self.failure = nil;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    if (token) {
        [request setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
        [request setValue:@"https://music.apple.com" forHTTPHeaderField:@"Origin"];
    }
    NSUInteger generation = self.generation;
    __weak typeof(self) weakSelf = self;
    self.fetched = ^(NSData *data, NSHTTPURLResponse *http, NSError *error) {
        typeof(self) owner = weakSelf;
        if (!owner || owner.generation != generation) return;
        NSInteger status = http.statusCode;
        BOOL transient = status == 429 || status >= 500 ||
            ([error.domain isEqual:NSURLErrorDomain] && error.code != NSURLErrorCancelled &&
             error.code != NSURLErrorDataNotAllowed && error.code != NSURLErrorServerCertificateUntrusted);
        NSTimeInterval delay = pow(2,attempt + 1);
        if (status == 429 || status == 503) {
            NSString *retry = [http valueForHTTPHeaderField:@"Retry-After"];
            NSScanner *scanner = [NSScanner scannerWithString:retry ?: @""];
            double seconds = 0;
            if ([scanner scanDouble:&seconds] && scanner.isAtEnd && isfinite(seconds) && seconds >= 0) delay = MAX(delay,seconds);
            else if (retry.length) {
                NSDateFormatter *formatter = [NSDateFormatter new];
                formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
                formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";
                delay = MAX(delay,[[formatter dateFromString:retry] timeIntervalSinceNow]);
            }
        }
        if (transient) owner.blockedUntil = NSDate.date.timeIntervalSince1970 + delay;
        if (transient && attempt < 2 && delay <= 60) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay*NSEC_PER_SEC)),dispatch_get_main_queue(), ^{
                if (owner.generation == generation && owner.completion)
                    [owner fetch:url authorization:token limit:limit attempt:attempt+1 completion:completion];
            });
        } else completion(data,http,error);
    };
    self.task = [self.session dataTaskWithRequest:request]; [self.task resume];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task
    didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completion {
    if (task != self.task) { completion(NSURLSessionResponseCancel); return; }
    self.response = [response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
    BOOL valid = self.response.statusCode == 200 && [response.URL isEqual:task.originalRequest.URL] &&
        response.expectedContentLength <= (int64_t)self.limit;
    if (!valid) self.failure = resolverError(self.response.statusCode ?: 1,@"Apple artwork HTTP response rejected");
    completion(valid ? NSURLSessionResponseAllow : NSURLSessionResponseCancel);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    if (task != self.task || self.failure) return;
    if (data.length > self.limit - self.body.length) {
        self.failure = resolverError(1,@"Apple artwork response exceeds size limit"); [task cancel];
    } else [self.body appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (task != self.task) return;
    SGAppleFetch done = self.fetched;
    NSData *body = self.body; NSHTTPURLResponse *response = self.response;
    NSError *failure = self.failure ?: error;
    self.task = nil; self.fetched = nil; self.body = nil;
    [session finishTasksAndInvalidate]; self.session = nil;
    if (done) done(body,response,failure);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request
    completionHandler:(void (^)(NSURLRequest *))completion { completion(nil); }
- (void)authorize {
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (!self.guest) self.token = self.configuredToken;
    if (tokenExpiry(self.token) > now + 300) { [self search]; return; }
    self.token = nil;
    if (!self.guest) {
        [self finish:nil error:resolverError(401,@"Replace the expired or invalid Apple developer token") confirmed:NO]; return;
    }
    [self fetch:[NSURL URLWithString:@"https://music.apple.com/us/new"] authorization:nil limit:4*1024*1024 attempt:0
        completion:^(NSData *data, NSHTTPURLResponse *http, NSError *error) {
        NSString *html = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:
            @"src=\"(/assets/index[^\"<>]*\\.js)\"" options:0 error:nil];
        NSTextCheckingResult *match = [re firstMatchInString:html ?: @"" options:0 range:NSMakeRange(0,html.length)];
        NSURL *script = match ? [NSURL URLWithString:[html substringWithRange:[match rangeAtIndex:1]]
            relativeToURL:[NSURL URLWithString:@"https://music.apple.com"]].absoluteURL : nil;
        if (error || ![script.host isEqual:@"music.apple.com"] || ![script.scheme isEqual:@"https"]) {
            [self finish:nil error:error ?: resolverError(401,@"Apple guest authorization script unavailable") confirmed:NO]; return;
        }
        [self fetch:script authorization:nil limit:8*1024*1024 attempt:0 completion:^(NSData *bytes, NSHTTPURLResponse *response, NSError *failure) {
            NSString *js = bytes ? [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] : nil;
            NSRegularExpression *jwt = [NSRegularExpression regularExpressionWithPattern:
                @"eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+" options:0 error:nil];
            if (!failure) for (NSTextCheckingResult *found in [jwt matchesInString:js ?: @"" options:0 range:NSMakeRange(0,js.length)]) {
                NSString *candidate = [js substringWithRange:found.range];
                if ([jwtPart(candidate,1)[@"iss"] isEqual:@"AMPWebPlay"] && tokenExpiry(candidate) > NSDate.date.timeIntervalSince1970 + 300) {
                    self.token = candidate; break;
                }
            }
            if (!self.token) [self finish:nil error:failure ?: resolverError(401,@"Apple guest authorization unavailable") confirmed:NO];
            else [self search];
        }];
    }];
}
- (void)search {
    NSString *host = self.guest ? @"amp-api.music.apple.com" : @"api.music.apple.com";
    NSURLComponents *url = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"https://%@/v1/catalog/us/search",host]];
    url.queryItems = @[[NSURLQueryItem queryItemWithName:@"term" value:[NSString stringWithFormat:@"%@ %@",self.artist,self.album]],
        [NSURLQueryItem queryItemWithName:@"types" value:@"albums"], [NSURLQueryItem queryItemWithName:@"limit" value:@"25"],
        [NSURLQueryItem queryItemWithName:@"extend[albums]" value:@"editorialVideo"], [NSURLQueryItem queryItemWithName:@"platform" value:@"web"]];
    [self searchPage:url.URL rows:[NSMutableArray new] page:0];
}
- (void)searchPage:(NSURL *)url rows:(NSMutableArray *)rows page:(NSUInteger)page {
    [self fetch:url authorization:self.token limit:2*1024*1024 attempt:0 completion:^(NSData *data, NSHTTPURLResponse *http, NSError *error) {
        if (error) {
            if ((http.statusCode == 401 || http.statusCode == 403) && self.guest && !self.refreshed) {
                self.refreshed = YES; self.token = nil; [self authorize];
            } else {
                if (http.statusCode == 401 || http.statusCode == 403) { self.token = nil; self.blockedUntil = NSDate.date.timeIntervalSince1970 + 60; }
                [self finish:nil error:error confirmed:NO];
            }
            return;
        }
        id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        id results = [root isKindOfClass:NSDictionary.class] ? root[@"results"] : nil;
        id albums = [results isKindOfClass:NSDictionary.class] ? results[@"albums"] : nil;
        if (![results isKindOfClass:NSDictionary.class] ||
            (albums && (![albums isKindOfClass:NSDictionary.class] || ![albums[@"data"] isKindOfClass:NSArray.class]))) {
            [self finish:nil error:resolverError(1,@"Malformed Apple album search response") confirmed:NO]; return;
        }
        for (id row in albums ? albums[@"data"] : @[]) {
            id a = [row isKindOfClass:NSDictionary.class] ? row[@"attributes"] : nil;
            if (![a isKindOfClass:NSDictionary.class] || ![a[@"name"] isKindOfClass:NSString.class] ||
                ![a[@"artistName"] isKindOfClass:NSString.class] ||
                (a[@"editorialVideo"] && ![a[@"editorialVideo"] isKindOfClass:NSDictionary.class])) {
                [self finish:nil error:resolverError(1,@"Malformed Apple album metadata") confirmed:NO]; return;
            }
            [rows addObject:row];
        }
        NSArray *matches = SGAppleArtworkMatches(rows,self.artist,self.album);
        BOOL exact = matches.count && [SGAppleArtworkNormalize(matches.firstObject[@"attributes"][@"name"])
            isEqual:SGAppleArtworkNormalize(self.album)];
        id next = albums[@"next"];
        if (next && !exact) {
            NSURL *more = [next isKindOfClass:NSString.class] ? [NSURL URLWithString:next relativeToURL:url].absoluteURL : nil;
            if (page >= 3 || ![more.host isEqual:url.host] || ![more.scheme isEqual:@"https"] ||
                ![more.path isEqual:url.path] || more.user || more.password || more.fragment || more.port) {
                [self finish:nil error:resolverError(1,@"Incomplete or invalid Apple album search pagination") confirmed:NO]; return;
            }
            [self searchPage:more rows:rows page:page+1]; return;
        }
        NSURL *motion = nil;
        for (NSDictionary *row in matches) {
            motion = SGAppleArtworkMotionURL(row[@"attributes"],self.ratio);
            if (motion) break;
        }
        if (!motion) {
            BOOL malformed = NO;
            for (NSDictionary *row in matches) if ([row[@"attributes"][@"editorialVideo"] count]) malformed = YES;
            [self finish:nil error:malformed ? resolverError(1,@"Unsupported Apple motion artwork metadata") : nil confirmed:!malformed];
            return;
        }
        [self playlist:motion depth:0];
    }];
}
- (void)playlist:(NSURL *)url depth:(NSUInteger)depth {
    if ([url.pathExtension.lowercaseString isEqual:@"mp4"]) { [self finish:url error:nil confirmed:NO]; return; }
    [self fetch:url authorization:nil limit:256*1024 attempt:0 completion:^(NSData *data, NSHTTPURLResponse *http, NSError *error) {
        if (error) { [self finish:nil error:error confirmed:NO]; return; }
        BOOL master = NO;
        NSURL *clip = SGAppleArtworkPlaylistURL([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],url,self.ratio,&master,&error);
        if (!clip || (master && depth >= 1)) {
            [self finish:nil error:error ?: resolverError(1,@"Nested HLS masters are unsupported") confirmed:NO]; return;
        }
        if (master) [self playlist:clip depth:depth+1];
        else [self finish:clip error:nil confirmed:NO];
    }];
}
@end
