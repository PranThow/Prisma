// Independent fallback for Spotify's imported mDNS sockets. The supplied decrypted 9.1.78 binary
// (UUID C712370B-44CD-35C8-A058-4FBED1AD0758) imports setsockopt/sendto/recvfrom/close.
// System Bonjour discovers declared services. Private loopback envelopes wake the existing socket;
// recvfrom unwraps them into bounded DNS records and the service's real address, never credentials.
#import "Core/SGCore.h"
#import "Core/SGRebind.h"
#import "ConnectDiscovery.h"
#import "SGMDNSPacket.h"
#import <arpa/inet.h>
#import <errno.h>
#import <pthread.h>
#import <sys/socket.h>
#import <unistd.h>

typedef struct { int fd; bool used; unsigned services; uint8_t cookie[16]; } SGDiscoverySocket;
typedef struct { uint8_t magic[4], cookie[16]; struct sockaddr_storage source; } SGDiscoveryEnvelope;
enum { SGDiscoverySockets = 16 };
static SGDiscoverySocket sg_sockets[SGDiscoverySockets];
static pthread_mutex_t sg_lock = PTHREAD_MUTEX_INITIALIZER;
static int (*sg_option)(int, int, int, const void *, socklen_t);
static ssize_t (*sg_send)(int, const void *, size_t, int, const struct sockaddr *, socklen_t);
static ssize_t (*sg_receive)(int, void *, size_t, int, struct sockaddr *, socklen_t *);
static int (*sg_close)(int);

SGModRow *SGConnectDiscoveryRow(void) {
    return SGWithSymbol(SGSwitchRow(@"Bonjour Connect discovery",
        @"Bridge nearby devices when signing blocks multicast; restart required", SGKeyConnectBonjourDiscovery), @"hifispeaker.2");
}
static SGDiscoverySocket *sg_find(int fd, bool create) {
    SGDiscoverySocket *freeSlot = NULL;
    for (unsigned i = 0; i < SGDiscoverySockets; i++) {
        if (sg_sockets[i].used && sg_sockets[i].fd == fd) return &sg_sockets[i];
        if (!sg_sockets[i].used && !freeSlot) freeSlot = &sg_sockets[i];
    }
    if (create && freeSlot) {
        *freeSlot = (SGDiscoverySocket){.fd = fd, .used = true};
        arc4random_buf(freeSlot->cookie, sizeof(freeSlot->cookie));
        return freeSlot;
    }
    return NULL;
}
static bool sg_snapshot(int fd, SGDiscoverySocket *result) {
    pthread_mutex_lock(&sg_lock);
    SGDiscoverySocket *slot = sg_find(fd, false);
    if (slot) *result = *slot;
    pthread_mutex_unlock(&sg_lock);
    return slot != NULL;
}
static bool sg_multicast(const struct sockaddr *address, socklen_t length) {
    if (!address || length < offsetof(struct sockaddr, sa_data)) return false;
    if (address->sa_family == AF_INET && length >= sizeof(struct sockaddr_in)) {
        const struct sockaddr_in *v4 = (const void *)address;
        return ntohs(v4->sin_port) == 5353 && ntohl(v4->sin_addr.s_addr) == 0xe00000fb;
    }
    if (address->sa_family == AF_INET6 && length >= sizeof(struct sockaddr_in6)) {
        static const uint8_t group[] = {0xff, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xfb};
        const struct sockaddr_in6 *v6 = (const void *)address;
        return ntohs(v6->sin6_port) == 5353 && !memcmp(v6->sin6_addr.s6_addr, group, 16);
    }
    return false;
}
static bool sg_membership(int level, int option, const void *data, socklen_t length) {
    if (level == IPPROTO_IP && option == IP_ADD_MEMBERSHIP && length >= sizeof(struct ip_mreq))
        return ntohl(((const struct ip_mreq *)data)->imr_multiaddr.s_addr) == 0xe00000fb;
    if (level == IPPROTO_IPV6 && option == IPV6_JOIN_GROUP && length >= sizeof(struct ipv6_mreq)) {
        const struct ipv6_mreq *request = data;
        struct sockaddr_in6 v6 = {.sin6_family = AF_INET6, .sin6_port = htons(5353), .sin6_addr = request->ipv6mr_multiaddr};
        return sg_multicast((const void *)&v6, sizeof(v6));
    }
    return false;
}

@interface SGConnectBonjour : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate>
- (void)query:(unsigned)services;
@end
static SGConnectBonjour *sg_bonjour; // main queue only

static void sg_query(unsigned services) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!sg_bonjour) sg_bonjour = [SGConnectBonjour new];
        [sg_bonjour query:services];
    });
}
static int sg_setsockopt(int fd, int level, int option, const void *data, socklen_t length) {
    int result = sg_option(fd, level, option, data, length), error = errno;
    if (result == -1 && (error == EPERM || error == EACCES) && data && sg_membership(level, option, data, length)) {
        int type = 0; socklen_t size = sizeof(type);
        if (!getsockopt(fd, SOL_SOCKET, SO_TYPE, &type, &size) && type == SOCK_DGRAM) {
            pthread_mutex_lock(&sg_lock);
            bool registered = sg_find(fd, true) != NULL;
            pthread_mutex_unlock(&sg_lock);
            if (registered) return 0;
        }
    }
    errno = error; return result;
}
static ssize_t sg_sendto(int fd, const void *bytes, size_t count, int flags, const struct sockaddr *address, socklen_t length) {
    SGDiscoverySocket snapshot;
    unsigned services = bytes && sg_multicast(address, length) ? SGDNSQuestions(bytes, count) : 0;
    if (services && sg_snapshot(fd, &snapshot)) {
        if (services) {
            pthread_mutex_lock(&sg_lock);
            SGDiscoverySocket *slot = sg_find(fd, false);
            bool registered = slot && !memcmp(slot->cookie, snapshot.cookie, 16);
            if (registered) slot->services |= services;
            pthread_mutex_unlock(&sg_lock);
            if (registered) { sg_query(services); return (ssize_t)count; }
        }
    }
    ssize_t result = sg_send(fd, bytes, count, flags, address, length);
    int error = errno;
    // Some OS versions reject transmission rather than membership.
    if (result < 0 && services && (error == EPERM || error == EACCES)) {
        int type = 0; socklen_t size = sizeof(type);
        if (!getsockopt(fd, SOL_SOCKET, SO_TYPE, &type, &size) && type == SOCK_DGRAM) {
            pthread_mutex_lock(&sg_lock);
            SGDiscoverySocket *slot = sg_find(fd, true);
            if (slot) slot->services |= services;
            pthread_mutex_unlock(&sg_lock);
            if (slot) { sg_query(services); return (ssize_t)count; }
        }
    }
    errno = error; return result;
}
static ssize_t sg_recvfrom(int fd, void *bytes, size_t count, int flags, struct sockaddr *address, socklen_t *length) {
    SGDiscoverySocket snapshot;
    if (!bytes || (address && !length) || count > 65535 || !sg_snapshot(fd, &snapshot))
        return sg_receive(fd, bytes, count, flags, address, length);
    size_t capacity = MAX(count, SGDNSMaximum) + sizeof(SGDiscoveryEnvelope);
    uint8_t *temporary = malloc(capacity);
    if (!temporary) return sg_receive(fd, bytes, count, flags, address, length);
    struct sockaddr_storage from = {0}; socklen_t fromLength = sizeof(from);
    ssize_t received = sg_receive(fd, temporary, capacity, flags, (void *)&from, &fromLength);
    int error = errno;
    const uint8_t *payload = temporary;
    size_t available = received > 0 ? MIN((size_t)received, capacity) : 0, actual = received > 0 ? (size_t)received : 0;
    bool loopback = (from.ss_family == AF_INET && ntohl(((struct sockaddr_in *)&from)->sin_addr.s_addr) == INADDR_LOOPBACK) ||
        (from.ss_family == AF_INET6 && IN6_IS_ADDR_LOOPBACK(&((struct sockaddr_in6 *)&from)->sin6_addr));
    if (loopback && available >= sizeof(SGDiscoveryEnvelope)) {
        SGDiscoveryEnvelope header; memcpy(&header, temporary, sizeof(header));
        SGDiscoverySocket current;
        if (!memcmp(header.magic, "SGMD", 4) && !memcmp(header.cookie, snapshot.cookie, 16) &&
            sg_snapshot(fd, &current) && !memcmp(current.cookie, snapshot.cookie, 16) &&
            (header.source.ss_family == AF_INET || header.source.ss_family == AF_INET6)) {
            payload += sizeof(header); available -= sizeof(header); actual -= sizeof(header);
            from = header.source;
            fromLength = from.ss_family == AF_INET ? sizeof(struct sockaddr_in) : sizeof(struct sockaddr_in6);
        }
    }
    if (received >= 0) {
        memcpy(bytes, payload, MIN(count, available));
        if (address && length) { memcpy(address, &from, MIN(*length, fromLength)); *length = fromLength; }
        // Darwin reports bytes copied; Linux accepts MSG_TRUNC to request the full datagram length.
        bool fullLength = false;
#if defined(__linux__)
        fullLength = (flags & MSG_TRUNC) != 0;
#endif
        received = fullLength ? (ssize_t)actual : (ssize_t)MIN(count, available);
    }
    free(temporary); errno = error; return received;
}
static int sg_socketclose(int fd) {
    pthread_mutex_lock(&sg_lock);
    SGDiscoverySocket *slot = sg_find(fd, false);
    if (slot) *slot = (SGDiscoverySocket){0};
    pthread_mutex_unlock(&sg_lock);
    if (slot) sg_query(0);
    return sg_close(fd);
}

@implementation SGConnectBonjour {
    NSArray<NSNetServiceBrowser *> *_browsers;
    NSMutableDictionary<NSString *, NSNetService *> *_services;
    NSMutableDictionary<NSString *, NSNumber *> *_attempts, *_retryAfter;
    NSMutableSet<NSString *> *_resolving;
    unsigned _searching;
    NSTimeInterval _lastReplay;
    NSTimeInterval _browserRetry[2];
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _services = [NSMutableDictionary new];
    _attempts = [NSMutableDictionary new]; _retryAfter = [NSMutableDictionary new]; _resolving = [NSMutableSet new];
    _browsers = @[[NSNetServiceBrowser new], [NSNetServiceBrowser new]];
    for (NSNetServiceBrowser *browser in _browsers) browser.delegate = self;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(suspended) name:UIApplicationWillResignActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resumed) name:UIApplicationDidBecomeActiveNotification object:nil];
    return self;
}
- (void)suspended {
    for (NSNetServiceBrowser *browser in _browsers) [browser stop];
    for (NSNetService *service in _services.allValues) { [service stopMonitoring]; [service stop]; }
    [_services removeAllObjects]; [_attempts removeAllObjects]; [_retryAfter removeAllObjects]; [_resolving removeAllObjects]; _searching = 0;
}
- (void)resumed {
    unsigned services = 0;
    pthread_mutex_lock(&sg_lock);
    for (unsigned i = 0; i < SGDiscoverySockets; i++) if (sg_sockets[i].used) services |= sg_sockets[i].services;
    pthread_mutex_unlock(&sg_lock);
    [self query:services];
}
- (void)query:(unsigned)services {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    services = 0;
    pthread_mutex_lock(&sg_lock);
    for (unsigned i = 0; i < SGDiscoverySockets; i++) if (sg_sockets[i].used) services |= sg_sockets[i].services;
    pthread_mutex_unlock(&sg_lock);
    if (!services) { [self suspended]; return; }
    NSArray *types = @[@"_spotify-connect._tcp.", @"_googlecast._tcp."];
    for (unsigned i = 0; i < 2; i++) if (!((1u << i) & services) && ((1u << i) & _searching)) {
        [_browsers[i] stop]; _searching &= ~(1u << i);
        for (NSNetService *service in _services.allValues) if ([service.type isEqualToString:types[i]]) {
            NSString *key = [self key:service];
            [service stopMonitoring]; [service stop]; [_services removeObjectForKey:key];
            [_attempts removeObjectForKey:key]; [_retryAfter removeObjectForKey:key]; [_resolving removeObject:key];
        }
    }
    for (unsigned i = 0; i < 2; i++) if ((services & (1u << i)) && !(_searching & (1u << i)) && NSProcessInfo.processInfo.systemUptime >= _browserRetry[i]) {
        _searching |= 1u << i;
        [_browsers[i] searchForServicesOfType:types[i] inDomain:@"local."];
    }
    if (NSDate.date.timeIntervalSince1970 - _lastReplay < 2) return;
    _lastReplay = NSDate.date.timeIntervalSince1970;
    for (NSNetService *service in _services.allValues) {
        NSString *key = [self key:service];
        if ((!service.hostName.length || !service.addresses.count) && ![_resolving containsObject:key] && NSProcessInfo.processInfo.systemUptime >= [_retryAfter[key] doubleValue]) {
            if ([_attempts[key] unsignedIntegerValue] >= 3) _attempts[key] = @0;
            [self resolve:service];
        }
        [self emit:service ttl:120];
    }
}
- (NSString *)key:(NSNetService *)service { return [@[service.type, service.domain, service.name] description]; }
- (void)resolve:(NSNetService *)service {
    NSString *key = [self key:service];
    if (_services[key] != service || [_resolving containsObject:key]) return;
    _attempts[key] = @([_attempts[key] unsignedIntegerValue] + 1);
    [_resolving addObject:key]; [service resolveWithTimeout:5];
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)more {
    // ponytail: 64 nearby services and 16 sockets; raise the bounded caps if device evidence needs it.
    NSString *key = [self key:service];
    if (_services[key] || _services.count >= 64 || !_searching) return;
    _services[key] = service; service.delegate = self; [self resolve:service];
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)more {
    NSNetService *existing = _services[[self key:service]];
    if (existing) {
        NSString *key = [self key:service];
        [self emit:existing ttl:0]; [existing stopMonitoring]; [existing stop];
        [_services removeObjectForKey:key]; [_attempts removeObjectForKey:key]; [_retryAfter removeObjectForKey:key]; [_resolving removeObject:key];
    }
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary *)error {
    NSUInteger index = [_browsers indexOfObjectIdenticalTo:browser];
    if (index < 2) { _searching &= ~(1u << index); _browserRetry[index] = NSProcessInfo.processInfo.systemUptime + 30; }
    SGLog(@"Connect: Bonjour unavailable (%@)", error[NSNetServicesErrorCode]);
}
- (void)netServiceDidResolveAddress:(NSNetService *)service {
    if (_services[[self key:service]] != service) return;
    [_resolving removeObject:[self key:service]];
    [service startMonitoring]; [self emit:service ttl:120];
}
- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)error {
    NSString *key = [self key:service];
    if (_services[key] != service) return;
    [_resolving removeObject:key];
    NSUInteger attempts = [_attempts[key] unsignedIntegerValue];
    NSTimeInterval delay = attempts >= 3 ? 30 : attempts * 2;
    _retryAfter[key] = @(NSProcessInfo.processInfo.systemUptime + delay);
    if (attempts >= 3) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self->_services[key] == service && UIApplication.sharedApplication.applicationState == UIApplicationStateActive) [self resolve:service];
    });
}
- (void)netService:(NSNetService *)service didUpdateTXTRecordData:(NSData *)data {
    if (_services[[self key:service]] == service) [self emit:service ttl:120];
}
- (void)emit:(NSNetService *)service ttl:(unsigned)ttl {
    if (!service.hostName.length || ![service.hostName.lowercaseString hasSuffix:@".local."] || service.port <= 0 || service.port > 65535) return;
    unsigned interest = [service.type.lowercaseString isEqualToString:@"_spotify-connect._tcp."] ? 1 :
        [service.type.lowercaseString isEqualToString:@"_googlecast._tcp."] ? 2 : 0;
    if (!interest) return;
    SGDNSPacket packet, type = {0}, instance = {0}, host = {0}, srv = {0}, text = {0};
    SGDNSBegin(&packet);
    NSString *typeName = [service.type stringByAppendingString:service.domain];
    NSData *name = [service.name dataUsingEncoding:NSUTF8StringEncoding];
    if (!SGDNSName(&type, typeName.UTF8String) || !SGDNSLabel(&instance, name.bytes, name.length) ||
        !SGDNSAppend(&instance, type.bytes, type.count) || !SGDNSName(&host, service.hostName.UTF8String) ||
        !SGDNSU16(&srv, 0) || !SGDNSU16(&srv, 0) || !SGDNSU16(&srv, (unsigned)service.port) || !SGDNSAppend(&srv, host.bytes, host.count)) return;
    NSData *txt = service.TXTRecordData;
    if (txt.length > 2048 || !SGDNSAppend(&text, txt.bytes, txt.length)) return;
    if (!text.count) { uint8_t zero = 0; SGDNSAppend(&text, &zero, 1); }
    if (!SGDNSRecord(&packet, &type, 12, ttl, &instance) || !SGDNSRecord(&packet, &instance, 33, ttl, &srv) || !SGDNSRecord(&packet, &instance, 16, ttl, &text)) return;
    struct sockaddr_storage source4 = {0}, source6 = {0}; unsigned addresses = 0;
    for (NSData *address in service.addresses) {
        if (++addresses > 8 || address.length < sizeof(struct sockaddr)) break;
        const struct sockaddr *sa = address.bytes; SGDNSPacket value = {0};
        if (sa->sa_family == AF_INET && address.length >= sizeof(struct sockaddr_in)) {
            const struct sockaddr_in *v4 = address.bytes;
            uint32_t ip = ntohl(v4->sin_addr.s_addr);
            if (!ip || (ip & 0xf0000000) == 0xe0000000 || ip == 0xffffffff) continue;
            SGDNSAppend(&value, &v4->sin_addr, 4);
            if (!SGDNSRecord(&packet, &host, 1, ttl, &value)) return;
            if (!source4.ss_family) { memcpy(&source4, v4, sizeof(*v4)); ((struct sockaddr_in *)&source4)->sin_port = htons(5353); }
        } else if (sa->sa_family == AF_INET6 && address.length >= sizeof(struct sockaddr_in6)) {
            const struct sockaddr_in6 *v6 = address.bytes;
            if (IN6_IS_ADDR_UNSPECIFIED(&v6->sin6_addr) || IN6_IS_ADDR_MULTICAST(&v6->sin6_addr)) continue;
            SGDNSAppend(&value, &v6->sin6_addr, 16);
            if (!SGDNSRecord(&packet, &host, 28, ttl, &value)) return;
            if (!source6.ss_family) { memcpy(&source6, v6, sizeof(*v6)); ((struct sockaddr_in6 *)&source6)->sin6_port = htons(5353); }
        }
    }
    if (!source4.ss_family && !source6.ss_family) return;
    SGDiscoverySocket sockets[SGDiscoverySockets];
    pthread_mutex_lock(&sg_lock); memcpy(sockets, sg_sockets, sizeof(sockets)); pthread_mutex_unlock(&sg_lock);
    for (unsigned i = 0; i < SGDiscoverySockets; i++) {
        SGDiscoverySocket *entry = &sockets[i];
        if (!entry->used || !(entry->services & interest)) continue;
        struct sockaddr_storage destination = {0}; socklen_t length = sizeof(destination);
        pthread_mutex_lock(&sg_lock);
        SGDiscoverySocket *live = sg_find(entry->fd, false);
        bool valid = live && !memcmp(live->cookie, entry->cookie, 16) && !getsockname(entry->fd, (void *)&destination, &length);
        pthread_mutex_unlock(&sg_lock);
        if (!valid) continue;
        if (destination.ss_family == AF_INET) {
            struct sockaddr_in *v4 = (void *)&destination;
            if (!v4->sin_port) continue;
            if (!v4->sin_addr.s_addr) v4->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        } else if (destination.ss_family == AF_INET6) {
            struct sockaddr_in6 *v6 = (void *)&destination;
            if (!v6->sin6_port) continue;
            if (IN6_IS_ADDR_UNSPECIFIED(&v6->sin6_addr)) v6->sin6_addr = in6addr_loopback;
        } else continue;
        struct sockaddr_storage source = destination.ss_family == AF_INET ? source4 : source6;
        if (!source.ss_family) continue;
        SGDiscoveryEnvelope envelope = {.magic = {'S', 'G', 'M', 'D'}, .source = source};
        memcpy(envelope.cookie, entry->cookie, 16);
        NSMutableData *wire = [NSMutableData dataWithBytes:&envelope length:sizeof(envelope)];
        [wire appendBytes:packet.bytes length:packet.count];
        int sender = socket(destination.ss_family, SOCK_DGRAM, 0);
        if (sender >= 0) {
            struct sockaddr_storage loopback = {0}; socklen_t loopbackLength;
            if (destination.ss_family == AF_INET) {
                struct sockaddr_in *v4 = (void *)&loopback;
                v4->sin_len = sizeof(*v4); v4->sin_family = AF_INET; v4->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
                loopbackLength = sizeof(*v4);
            } else {
                struct sockaddr_in6 *v6 = (void *)&loopback;
                v6->sin6_len = sizeof(*v6); v6->sin6_family = AF_INET6; v6->sin6_addr = in6addr_loopback;
                loopbackLength = sizeof(*v6);
            }
            if (!bind(sender, (void *)&loopback, loopbackLength)) sendto(sender, wire.bytes, wire.length, MSG_DONTWAIT, (void *)&destination, length);
            close(sender);
        }
    }
}
@end

%ctor {
    if (!SGEnabled(SGKeyConnectBonjourDiscovery)) return;
    // Install lifecycle/receive handling before any membership can be bridged.
    if (!SGRebindImport("close", sg_socketclose, (void **)&sg_close) || !sg_close ||
        !SGRebindImport("recvfrom", sg_recvfrom, (void **)&sg_receive) || !sg_receive ||
        !SGRebindImport("sendto", sg_sendto, (void **)&sg_send) || !sg_send) {
        SGLog(@"Connect: verified socket imports unavailable; Bonjour bridge disabled"); return;
    }
    SGRebindImport("setsockopt", sg_setsockopt, (void **)&sg_option);
}
