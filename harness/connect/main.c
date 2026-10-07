#include "Shared/Navigation/SGMDNSPacket.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    SGDNSPacket query = {0}; query.count = 12; query.bytes[5] = 2;
    assert(SGDNSName(&query, "_spotify-connect._tcp.local."));
    assert(SGDNSU16(&query, 12) && SGDNSU16(&query, 1));
    assert(SGDNSName(&query, "_ABC._sub._googlecast._tcp.local."));
    assert(SGDNSU16(&query, 12) && SGDNSU16(&query, 0x8001));
    assert(SGDNSQuestions(query.bytes, query.count) == 3);
    assert(!SGDNSQuestions(query.bytes, query.count - 1));
    query.bytes[2] = 0x80;
    assert(!SGDNSQuestions(query.bytes, query.count));
    query.bytes[2] = 0; query.bytes[5] = 1;
    query.bytes[12] = 0xc0; query.bytes[13] = 12;
    assert(!SGDNSQuestions(query.bytes, query.count)); // compressed-name self loop
    query.bytes[13] = 255;
    assert(!SGDNSQuestions(query.bytes, query.count)); // out-of-bounds pointer
    SGDNSPacket name = {0}, target = {0}, packet;
    assert(SGDNSName(&name, "_spotify-connect._tcp.local."));
    assert(SGDNSLabel(&target, "Living.Room", 11)); // dot inside an instance label is preserved
    assert(SGDNSAppend(&target, name.bytes, name.count));
    SGDNSBegin(&packet);
    assert(SGDNSRecord(&packet, &name, 12, 120, &target));
    assert(packet.records == 1 && packet.bytes[2] == 0x84 && packet.bytes[7] == 1);
    size_t cursor = 12; char decoded[256];
    assert(SGDNSReadName(packet.bytes, packet.count, &cursor, decoded));
    assert(!strcmp(decoded, "_spotify-connect._tcp.local."));
    assert(packet.bytes[cursor + 1] == 12 && packet.bytes[cursor + 3] == 1);
    assert(packet.bytes[cursor + 7] == 120);
    SGDNSBegin(&packet);
    assert(SGDNSRecord(&packet, &name, 12, 0, &target));
    assert(packet.bytes[cursor + 7] == 0); // service-removal goodbye
    size_t before = packet.count;
    target.count = 4097;
    assert(!SGDNSRecord(&packet, &name, 12, 120, &target) && packet.count == before);
    assert(SGDNSAppend(&name, NULL, 0) && !SGDNSAppend(&name, NULL, 1));
    assert(!SGDNSLabel(&name, "", 0));
    char longLabel[64]; memset(longLabel, 'a', sizeof(longLabel));
    assert(!SGDNSLabel(&name, longLabel, sizeof(longLabel)));
    assert(!SGDNSName(&name, "bad..local"));
    puts("bounded mDNS query, compression, response and goodbye checks passed");
}
