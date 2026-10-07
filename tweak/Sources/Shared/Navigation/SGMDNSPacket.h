// Bounded DNS names/records for the system-Bonjour → Spotify socket bridge.
#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

enum { SGDNSMaximum = 8192 };
typedef struct { uint8_t bytes[SGDNSMaximum]; size_t count; unsigned records; } SGDNSPacket;
static inline bool SGDNSAppend(SGDNSPacket *p, const void *bytes, size_t length) {
    if (!length) return true;
    if (!bytes) return false;
    if (length > sizeof(p->bytes) - p->count) return false;
    memcpy(p->bytes + p->count, bytes, length); p->count += length; return true;
}
static inline bool SGDNSU16(SGDNSPacket *p, unsigned value) {
    uint8_t bytes[] = {value >> 8, value}; return SGDNSAppend(p, bytes, 2);
}
static inline bool SGDNSLabel(SGDNSPacket *p, const char *label, size_t length) {
    if (!length || length > 63) return false;
    uint8_t size = (uint8_t)length;
    return SGDNSAppend(p, &size, 1) && SGDNSAppend(p, label, length);
}
static inline bool SGDNSName(SGDNSPacket *p, const char *name) {
    size_t length = strlen(name);
    if (!length || length > 254) return false;
    const char *start = name;
    for (const char *c = name; ; c++) {
        if (*c != '.' && *c) continue;
        if (c > start && !SGDNSLabel(p, start, (size_t)(c - start))) return false;
        if (!*c) break;
        if (c == start) return false;
        start = c + 1;
    }
    uint8_t zero = 0; return SGDNSAppend(p, &zero, 1);
}
static inline bool SGDNSReadName(const uint8_t *packet, size_t size, size_t *cursor, char name[256]) {
    size_t at = *cursor, used = 0; bool jumped = false;
    for (unsigned hops = 0; hops < 128; hops++) {
        if (at >= size) return false;
        unsigned length = packet[at++];
        if ((length & 0xc0) == 0xc0) {
            if (at >= size) return false;
            size_t target = ((length & 0x3f) << 8) | packet[at++];
            if (target >= size) return false;
            if (!jumped) *cursor = at;
            jumped = true; at = target; continue;
        }
        if (length & 0xc0 || length > 63 || length > size - at) return false;
        if (!length) {
            if (!jumped) *cursor = at;
            name[used] = 0; return true;
        }
        if (used + length + 1 >= 256) return false;
        for (unsigned i = 0; i < length; i++) {
            unsigned c = packet[at++];
            if (c < 32 || c > 126 || c == '.') return false;
            name[used++] = c >= 'A' && c <= 'Z' ? (char)(c + 32) : (char)c;
        }
        name[used++] = '.';
    }
    return false;
}
static inline unsigned SGDNSQuestions(const void *data, size_t size) {
    const uint8_t *packet = data;
    if (size < 12 || size > SGDNSMaximum || (packet[2] & 0xf8)) return 0;
    unsigned count = (packet[4] << 8) | packet[5], result = 0;
    if (!count || count > 16) return 0;
    size_t cursor = 12;
    for (unsigned i = 0; i < count; i++) {
        char name[256];
        if (!SGDNSReadName(packet, size, &cursor, name) || cursor + 4 > size) return 0;
        const char *services[] = {"_spotify-connect._tcp.local.", "_googlecast._tcp.local."};
        for (unsigned s = 0; s < 2; s++) {
            size_t n = strlen(name), suffix = strlen(services[s]);
            if (n >= suffix && !strcmp(name + n - suffix, services[s]) && (n == suffix || name[n - suffix - 1] == '.')) result |= 1u << s;
        }
        cursor += 4;
    }
    return result;
}
static inline void SGDNSBegin(SGDNSPacket *p) {
    memset(p, 0, sizeof(*p)); p->count = 12; p->bytes[2] = 0x84;
}
static inline bool SGDNSRecord(SGDNSPacket *p, const SGDNSPacket *name, unsigned type, unsigned ttl, const SGDNSPacket *value) {
    if (name->count > 255 || value->count > 4096 || p->records >= 32) return false;
    size_t before = p->count;
    uint8_t seconds[] = {ttl >> 24, ttl >> 16, ttl >> 8, ttl};
    if (!SGDNSAppend(p, name->bytes, name->count) || !SGDNSU16(p, type) ||
        !SGDNSU16(p, type == 12 ? 1 : 0x8001) || !SGDNSAppend(p, seconds, 4) ||
        !SGDNSU16(p, (unsigned)value->count) || !SGDNSAppend(p, value->bytes, value->count)) { p->count = before; return false; }
    p->records++; p->bytes[6] = p->records >> 8; p->bytes[7] = p->records;
    return true;
}
