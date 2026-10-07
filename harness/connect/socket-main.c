#define _DEFAULT_SOURCE 1
#include "Shared/Navigation/SGMDNSPacket.h"
#include <arpa/inet.h>
#include <assert.h>
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
#define MAX(a,b) ((a) > (b) ? (a) : (b))
#define MIN(a,b) ((a) < (b) ? (a) : (b))
static bool invalidate_after_unlock;
static int race_fd;
static int tracked_unlock(pthread_mutex_t *lock);
#define pthread_mutex_unlock tracked_unlock
#include "bridge.inc"
#undef pthread_mutex_unlock
static int tracked_unlock(pthread_mutex_t *lock) {
    int result = pthread_mutex_unlock(lock);
    if (invalidate_after_unlock) {
        invalidate_after_unlock = false;
        pthread_mutex_lock(&sg_lock);
        SGDiscoverySocket *slot = sg_find(race_fd, false); assert(slot);
        slot->cookie[0] ^= 1;
        pthread_mutex_unlock(&sg_lock);
    }
    return result;
}

static unsigned queries, last_query, denied_sends;
static void sg_query(unsigned services) { queries++; last_query = services; }
static int denied_option(int fd, int level, int option, const void *data, socklen_t size) {
    (void)fd; (void)level; (void)option; (void)data; (void)size;
    errno = EPERM; return -1;
}
static ssize_t denied_send(int fd, const void *data, size_t size, int flags, const struct sockaddr *address, socklen_t length) {
    (void)fd; (void)data; (void)size; (void)flags; (void)address; (void)length;
    denied_sends++; errno = EACCES; return -1;
}
static int receiver(struct sockaddr_in *address) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0); assert(fd >= 0);
    *address = (struct sockaddr_in){.sin_family = AF_INET, .sin_addr.s_addr = htonl(INADDR_LOOPBACK)};
#ifdef __APPLE__
    address->sin_len = sizeof(*address);
#endif
    assert(!bind(fd, (const void *)address, sizeof(*address)));
    socklen_t length = sizeof(*address); assert(!getsockname(fd, (void *)address, &length));
    struct timeval timeout = {.tv_sec = 1};
    assert(!setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)));
    return fd;
}
static void register_socket(int fd) {
    struct ip_mreq request = {.imr_multiaddr.s_addr = htonl(0xe00000fb)};
    assert(!sg_setsockopt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, &request, sizeof(request)));
}
static void send_wire(int sender, const struct sockaddr_in *destination, const SGDiscoveryEnvelope *header, const SGDNSPacket *packet) {
    uint8_t wire[sizeof(*header) + SGDNSMaximum];
    memcpy(wire, header, sizeof(*header)); memcpy(wire + sizeof(*header), packet->bytes, packet->count);
    size_t length = sizeof(*header) + packet->count;
    assert(sendto(sender, wire, length, 0, (const void *)destination, sizeof(*destination)) == (ssize_t)length);
}
static uint8_t external_wire[sizeof(SGDiscoveryEnvelope) + SGDNSMaximum];
static size_t external_length;
static ssize_t external_receive(int fd, void *output, size_t capacity, int flags, struct sockaddr *source, socklen_t *length) {
    (void)fd; (void)flags;
    assert(capacity >= external_length); memcpy(output, external_wire, external_length);
    struct sockaddr_in peer = {.sin_family = AF_INET, .sin_port = htons(5353)};
    assert(inet_pton(AF_INET, "203.0.113.8", &peer.sin_addr) == 1);
    if (source && length) { memcpy(source, &peer, MIN(*length, sizeof(peer))); *length = sizeof(peer); }
    return (ssize_t)external_length;
}
int main(void) {
    sg_option = denied_option; sg_send = denied_send; sg_receive = recvfrom; sg_close = close;
    struct sockaddr_in destination; int fd = receiver(&destination);
    int sender = socket(AF_INET, SOCK_DGRAM, 0); assert(sender >= 0);
    register_socket(fd);
    SGDiscoverySocket snapshot; assert(sg_snapshot(fd, &snapshot));
    SGDiscoveryEnvelope header = {.magic = {'S','G','M','D'}};
    memcpy(header.cookie, snapshot.cookie, sizeof(header.cookie));
    struct sockaddr_in service = {.sin_family = AF_INET, .sin_port = htons(5353)};
#ifdef __APPLE__
    service.sin_len = sizeof(service);
#endif
    assert(inet_pton(AF_INET, "192.0.2.33", &service.sin_addr) == 1);
    memcpy(&header.source, &service, sizeof(service));
    SGDNSPacket packet, name = {0}, target = {0}; SGDNSBegin(&packet);
    assert(SGDNSName(&name, "_spotify-connect._tcp.local."));
    assert(SGDNSLabel(&target, "Device", 6)); assert(SGDNSAppend(&target, name.bytes, name.count));
    assert(SGDNSRecord(&packet, &name, 12, 120, &target));
    uint8_t output[sizeof(header) + SGDNSMaximum]; struct sockaddr_storage address;
    socklen_t address_length = sizeof(address);
    send_wire(sender, &destination, &header, &packet);
    assert(sg_recvfrom(fd, output, 4, MSG_PEEK, (void *)&address, &address_length) == 4);
    assert(!memcmp(output, packet.bytes, 4)); assert(address_length == sizeof(service));
    assert(((struct sockaddr_in *)&address)->sin_addr.s_addr == service.sin_addr.s_addr);
    assert(((struct sockaddr_in *)&address)->sin_port == htons(5353));
    address_length = sizeof(address);
    assert(sg_recvfrom(fd, output, sizeof(output), 0, (void *)&address, &address_length) == (ssize_t)packet.count);
    assert(!memcmp(output, packet.bytes, packet.count));
    // A short output sockaddr reports its actual size without overwriting caller storage.
    send_wire(sender, &destination, &header, &packet);
    uint8_t short_address[32]; memset(short_address, 0x5a, sizeof(short_address)); address_length = 4;
#if defined(__linux__)
    ssize_t expected_length = (ssize_t)packet.count;
#else
    ssize_t expected_length = 3;
#endif
    assert(sg_recvfrom(fd, output, 3, MSG_TRUNC, (void *)short_address, &address_length) == expected_length);
    assert(address_length == sizeof(service));
    for (unsigned i = 4; i < sizeof(short_address); i++) assert(short_address[i] == 0x5a);
    // Even a matching cookie cannot unwrap a packet received from a non-loopback source.
    memcpy(external_wire, &header, sizeof(header));
    memcpy(external_wire + sizeof(header), packet.bytes, packet.count);
    external_length = sizeof(header) + packet.count;
    sg_receive = external_receive; address_length = sizeof(address);
    assert(sg_recvfrom(fd, output, sizeof(output), 0, (void *)&address, &address_length) == (ssize_t)external_length);
    assert(!memcmp(output, "SGMD", 4));
    assert(((struct sockaddr_in *)&address)->sin_addr.s_addr != service.sin_addr.s_addr);
    sg_receive = recvfrom;
    // Zero-byte reads still consume the datagram without copying payload.
    send_wire(sender, &destination, &header, &packet);
    assert(sg_recvfrom(fd, output, 0, 0, NULL, NULL) == 0);
    assert(sg_recvfrom(fd, output, sizeof(output), MSG_DONTWAIT, NULL, NULL) == -1);
    assert(errno == EAGAIN || errno == EWOULDBLOCK);
    // Wrong cookies and unsupported embedded source families remain ordinary loopback datagrams.
    header.cookie[0] ^= 1;
    send_wire(sender, &destination, &header, &packet);
    address_length = sizeof(address);
    assert(sg_recvfrom(fd, output, sizeof(output), 0, (void *)&address, &address_length) == (ssize_t)(sizeof(header) + packet.count));
    assert(!memcmp(output, "SGMD", 4));
    assert(((struct sockaddr_in *)&address)->sin_addr.s_addr == htonl(INADDR_LOOPBACK));
    header.cookie[0] ^= 1; header.source.ss_family = AF_UNSPEC;
    send_wire(sender, &destination, &header, &packet);
    assert(sg_recvfrom(fd, output, sizeof(output), 0, NULL, NULL) == (ssize_t)(sizeof(header) + packet.count));
    memcpy(&header.source, &service, sizeof(service));
    // Reused descriptors get a fresh cookie; replies leased to the old registration cannot unwrap.
    pthread_mutex_lock(&sg_lock); *sg_find(fd, false) = (SGDiscoverySocket){0}; pthread_mutex_unlock(&sg_lock);
    register_socket(fd); SGDiscoverySocket fresh; assert(sg_snapshot(fd, &fresh));
    assert(memcmp(snapshot.cookie, fresh.cookie, sizeof(fresh.cookie)));
    send_wire(sender, &destination, &header, &packet);
    assert(sg_recvfrom(fd, output, sizeof(output), 0, NULL, NULL) == (ssize_t)(sizeof(header) + packet.count));
    // A denied multicast send registers interest even when membership was never attempted.
    struct sockaddr_in second_address; int second = receiver(&second_address);
    SGDNSPacket query = {0}; query.count = 12; query.bytes[5] = 1;
    assert(SGDNSName(&query, "_spotify-connect._tcp.local."));
    assert(SGDNSU16(&query, 12) && SGDNSU16(&query, 1));
    struct sockaddr_in multicast = {.sin_family = AF_INET, .sin_port = htons(5353), .sin_addr.s_addr = htonl(0xe00000fb)};
    assert(sg_sendto(second, query.bytes, query.count, 0, (const void *)&multicast, sizeof(multicast)) == (ssize_t)query.count);
    assert(last_query == 1 && queries > 0); assert(sg_snapshot(second, &fresh) && fresh.services == 1);
    // Force descriptor registration replacement after the snapshot lock releases.
    // A stale snapshot must reach the original send instead of claiming its old registration succeeded.
    race_fd = second; invalidate_after_unlock = true;
    unsigned previous_sends = denied_sends;
    assert(sg_sendto(second, query.bytes, query.count, 0, (const void *)&multicast, sizeof(multicast)) == (ssize_t)query.count);
    assert(denied_sends == previous_sends + 1);
    // A short sockaddr is rejected before family-specific parsing or interest registration.
    uint8_t short_destination[1] = {0};
    assert(sg_sendto(second, query.bytes, query.count, 0, (const void *)short_destination, sizeof(short_destination)) == -1);
    assert(errno == EACCES);
    unsigned before = queries;
    assert(!sg_socketclose(second)); assert(!sg_snapshot(second, &fresh)); assert(queries == before + 1 && last_query == 0);
    assert(!sg_socketclose(fd)); assert(!sg_snapshot(fd, &fresh)); close(sender);
    puts("Connect actual socket-wrapper checks passed (peek/truncation/address bounds/cookies/send fallback/close)");
    return 0;
}
