// Spotify 9.1.78 UUID C712370B-44CD-35C8-A058-4FBED1AD0758:
// GCKCastDeviceMDNSScanner's class factory has encoding @48@0:8B16B20@24d32d40.
// Select the SDK's Bonjour implementation; its raw multicast sockets require a signing entitlement.
#import "Core/SGCore.h"
#import "CastDiscovery.h"
#include <string.h>

SGModRow *SGCastDiscoveryRow(void) {
    return SGWithSymbol(SGSwitchRow(@"Bonjour Cast discovery",
        @"Find nearby Cast devices using system Bonjour; restart required", SGKeyCastBonjourDiscovery), @"hifispeaker");
}

%hook GCKCastDeviceMDNSScanner
+ (id)createMDNSServiceBrowserWithCustomMulticastEnabled:(BOOL)custom
    useUnicastQueries:(BOOL)unicast networkReachability:(id)reachability
    rescanInterval:(double)rescan deviceTimeoutInterval:(double)timeout {
    return %orig(NO, unicast, reachability, rescan, timeout);
}
%end

%ctor {
    if (!SGEnabled(SGKeyCastBonjourDiscovery)) return;
    Class scanner = NSClassFromString(@"GCKCastDeviceMDNSScanner");
    SEL factory = @selector(createMDNSServiceBrowserWithCustomMulticastEnabled:useUnicastQueries:networkReachability:rescanInterval:deviceTimeoutInterval:);
    Method method = class_getClassMethod(scanner, factory);
    // A changed ABI must disable this hook rather than call with the wrong arguments.
    if (!method || strcmp(method_getTypeEncoding(method), "@48@0:8B16B20@24d32d40")) {
        SGLog(@"Cast: the verified Bonjour factory is unavailable");
        return;
    }
    %init;
}
