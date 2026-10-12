/* SPDX-License-Identifier: MIT
 * Bounded WLFW userspace initialization. QMI fields follow the
 * pinned Samsung kernel's wlan_firmware_service_v01.[ch]. Only matching stock
 * board data is sent to volatile WLAN firmware; no NV partition is accessed. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <linux/qrtr.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

static uint16_t transaction;
static int fw_ready;
static int msa_ready;
static uint64_t fw_status;
static uint32_t board_id = 0xff;
static uint32_t chip_id, chip_family;

static unsigned int le16(const unsigned char *p) { return p[0] | ((unsigned int)p[1] << 8); }
static unsigned int le32(const unsigned char *p) { return le16(p) | (le16(p + 2) << 16); }
static void put16(unsigned char *p, unsigned int n) { p[0] = n; p[1] = n >> 8; }
static void put32(unsigned char *p, unsigned int n) { put16(p, n); put16(p + 2, n >> 16); }

static long long now_ms(void)
{
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts)) exit(1);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static size_t tlv(unsigned char *p, unsigned int type, const void *data, size_t n)
{
    p[0] = type;
    put16(p + 1, n);
    memcpy(p + 3, data, n);
    return n + 3;
}

static size_t tlv_u8(unsigned char *p, unsigned int type, unsigned char n)
{
    return tlv(p, type, &n, 1);
}

static size_t tlv_u32(unsigned char *p, unsigned int type, unsigned int n)
{
    unsigned char value[4];
    put32(value, n);
    return tlv(p, type, value, 4);
}

static int parse_response(const unsigned char *p, size_t n, unsigned int message)
{
    int result_seen = 0;
    for (size_t offset = 7; offset < n;) {
        if (offset + 3 > n) return -1;
        unsigned int type = p[offset], size = le16(p + offset + 1);
        offset += 3;
        if (offset + size > n) return -1;
        const unsigned char *data = p + offset;
        if (type == 2 && size == 4) {
            printf("QMI 0x%04x result %u, error %u\n", message, le16(data), le16(data + 2));
            if (le16(data)) return -1;
            result_seen = 1;
        }
        if (message == 0x20 && type == 0x10 && size == 8) {
            fw_status = (uint64_t)le32(data) | ((uint64_t)le32(data + 4) << 32);
            printf("Firmware status 0x%llx\n", (unsigned long long)fw_status);
        }
        if (message == 0x24 && type == 0x10 && size == 8) {
            chip_id = le32(data);
            chip_family = le32(data + 4);
            printf("Chip ID 0x%x, family 0x%x\n", chip_id, chip_family);
        }
        if (message == 0x24 && type == 0x11 && size == 4) {
            board_id = le32(data);
            printf("Board ID 0x%x\n", board_id);
        }
        offset += size;
    }
    return result_seen ? 0 : -1;
}

static int request(int fd, unsigned int message, const unsigned char *payload, size_t size)
{
    unsigned char packet[6400];
    if (size + 7 > sizeof(packet)) return -1;
    uint16_t tid = ++transaction;
    packet[0] = 0;
    put16(packet + 1, tid);
    put16(packet + 3, message);
    put16(packet + 5, size);
    if (size) memcpy(packet + 7, payload, size);
    if (send(fd, packet, size + 7, 0) != (ssize_t)size + 7) { perror("QMI send"); return -1; }
    long long deadline = now_ms() + 5000;
    while (now_ms() < deadline) {
        struct pollfd pfd = {.fd = fd, .events = POLLIN};
        int remaining = deadline - now_ms();
        if (remaining <= 0) break;
        int ready = poll(&pfd, 1, remaining);
        if (ready < 0 && errno == EINTR) continue;
        if (ready != 1) break;
        ssize_t n = recv(fd, packet, sizeof(packet), 0);
        if (n < 7 || le16(packet + 5) != n - 7) return -1;
        if (packet[0] == 4) {
            unsigned int indication = le16(packet + 3);
            printf("WLFW indication 0x%04x\n", indication);
            if (indication == 0x21) fw_ready = 1;
            if (indication == 0x2b) msa_ready = 1;
            continue;
        }
        if (packet[0] != 2 || le16(packet + 1) != tid || le16(packet + 3) != message) {
            fprintf(stderr, "Unexpected QMI response\n");
            return -1;
        }
        return parse_response(packet, n, message);
    }
    fprintf(stderr, "QMI 0x%04x timeout\n", message);
    return -1;
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    if (argc != 4) { fprintf(stderr, "Usage: %s QRTR_NODE QRTR_PORT MATCHING_STOCK_BDF\n", argv[0]); return 2; }
    int bdf = open(argv[3], O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    struct stat info;
    if (bdf < 0 || fstat(bdf, &info) || !S_ISREG(info.st_mode) || info.st_size <= 0 || info.st_size > 1024 * 1024) {
        fprintf(stderr, "Invalid stock BDF file\n"); return 1;
    }
    struct sockaddr_qrtr peer = {.sq_family = AF_QIPCRTR,
        .sq_node = strtoul(argv[1], NULL, 10), .sq_port = strtoul(argv[2], NULL, 10)};
    int fd = socket(AF_QIPCRTR, SOCK_DGRAM | SOCK_CLOEXEC, 0);
    if (fd < 0 || connect(fd, (struct sockaddr *)&peer, sizeof(peer))) { perror("QRTR connection"); return 1; }
    unsigned char payload[6300];
    size_t size = 0;
    size += tlv_u8(payload + size, 0x10, 1); /* FW_READY */
    size += tlv_u8(payload + size, 0x13, 1); /* MSA_READY */
    size += tlv_u8(payload + size, 0x17, 1); /* FW_MEM_READY */
    size += tlv_u8(payload + size, 0x18, 1); /* FW_INIT_DONE */
    /* Anonymous userspace client; the kernel retains its separate KERNEL ID. */
    if (request(fd, 0x20, payload, size)) return 1;
    if (fw_status & 2) { puts("Firmware already ready; no board data sent"); return 0; }
    if (!(fw_status & 4) && !msa_ready) {
        long long deadline = now_ms() + 5000;
        while (!msa_ready && now_ms() < deadline) {
            struct pollfd pfd = {.fd = fd, .events = POLLIN};
            int remaining = deadline - now_ms();
            if (remaining <= 0 || poll(&pfd, 1, remaining) != 1) break;
            ssize_t n = recv(fd, payload, sizeof(payload), 0);
            if (n < 7 || payload[0] != 4 || le16(payload + 5) != n - 7) return 1;
            unsigned int indication = le16(payload + 3);
            printf("WLFW indication 0x%04x\n", indication);
            if (indication == 0x2b) msa_ready = 1;
        }
        if (!msa_ready) { fprintf(stderr, "MSA not ready; no board data sent\n"); return 1; }
    }
    if (request(fd, 0x24, NULL, 0)) return 1;
    if (chip_id != 0x150 || chip_family != 0x4002) {
        fprintf(stderr, "Unsupported WLAN chip; no board data sent\n"); return 1;
    }
    if (board_id != 0xff) { fprintf(stderr, "Firmware requests board 0x%x; generic stock BDF not selected\n", board_id); return 1; }
    printf("Sending matching stock BDF: %lld bytes\n", (long long)info.st_size);
    unsigned char data[6146];
    size_t sent = 0;
    unsigned int segment = 0;
    while (sent < (size_t)info.st_size) {
        size_t count = info.st_size - sent;
        if (count > 6144) count = 6144;
        if (read(bdf, data + 2, count) != (ssize_t)count) return 1;
        put16(data, count);
        size = 0;
        size += tlv_u8(payload + size, 1, 1); /* valid */
        size += tlv_u32(payload + size, 0x10, 0); /* file_id */
        size += tlv_u32(payload + size, 0x11, info.st_size);
        size += tlv_u32(payload + size, 0x12, segment);
        size += tlv(payload + size, 0x13, data, count + 2);
        size += tlv_u8(payload + size, 0x14, sent + count == (size_t)info.st_size);
        size += tlv_u8(payload + size, 0x15, 0); /* BIN board data */
        if (request(fd, 0x25, payload, size)) return 1;
        sent += count;
        printf("Board data accepted: segment %u, cumulative %zu bytes\n", segment++, sent);
    }
    close(bdf);
    /* No Linux calibration cache is available. Advertise an empty inventory,
     * as stock cnss-daemon does on its first run; no calibration is fabricated. */
    size = tlv_u8(payload, 1, 0);
    if (request(fd, 0x26, payload, size)) return 1;
    long long deadline = now_ms() + 10000;
    while (!fw_ready && now_ms() < deadline) {
        struct pollfd pfd = {.fd = fd, .events = POLLIN};
        int remaining = deadline - now_ms();
        if (remaining <= 0 || poll(&pfd, 1, remaining) != 1) break;
        ssize_t n = recv(fd, payload, sizeof(payload), 0);
        if (n < 7 || payload[0] != 4 || le16(payload + 5) != n - 7) return 1;
        unsigned int indication = le16(payload + 3);
        printf("WLFW indication 0x%04x\n", indication);
        if (indication == 0x21) fw_ready = 1;
    }
    close(fd);
    if (!fw_ready) { fprintf(stderr, "Board data accepted, but FW_READY not observed\n"); return 1; }
    puts("WLFW_INITIALIZATION_READY");
    return 0;
}
