/* Bounded read-only WLFW capability query. Wire format follows the pinned
 * downstream kernel's drivers/soc/qcom/wlan_firmware_service_v01.[ch]. */
#include <errno.h>
#include <linux/qrtr.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

static unsigned int le16(const unsigned char *p)
{
    return p[0] | ((unsigned int)p[1] << 8);
}

static unsigned int le32(const unsigned char *p)
{
    return le16(p) | (le16(p + 2) << 16);
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "Usage: %s QRTR_NODE QRTR_PORT\n", argv[0]);
        return 2;
    }
    struct sockaddr_qrtr peer = {
        .sq_family = AF_QIPCRTR,
        .sq_node = strtoul(argv[1], NULL, 10),
        .sq_port = strtoul(argv[2], NULL, 10),
    };
    int fd = socket(AF_QIPCRTR, SOCK_DGRAM | SOCK_CLOEXEC, 0);
    if (fd < 0 || connect(fd, (struct sockaddr *)&peer, sizeof(peer))) {
        perror("QRTR connection");
        return 1;
    }
    /* Request, transaction 1, CAP_REQ 0x24, empty payload. */
    unsigned char request[7] = {0, 1, 0, 0x24, 0, 0, 0};
    if (send(fd, request, sizeof(request), 0) != sizeof(request)) {
        perror("CAP_REQ");
        return 1;
    }
    struct pollfd pfd = {.fd = fd, .events = POLLIN};
    if (poll(&pfd, 1, 5000) != 1) {
        fprintf(stderr, "Capability query timed out\n");
        return 1;
    }
    unsigned char response[512];
    ssize_t length = recv(fd, response, sizeof(response), 0);
    close(fd);
    if (length < 7 || response[0] != 2 || le16(response + 1) != 1 ||
        le16(response + 3) != 0x24 || le16(response + 5) != length - 7) {
        fprintf(stderr, "Malformed or unexpected capability response\n");
        return 1;
    }
    int result_seen = 0;
    for (size_t offset = 7; offset < (size_t)length;) {
        if (offset + 3 > (size_t)length) return 1;
        unsigned int type = response[offset];
        unsigned int size = le16(response + offset + 1);
        offset += 3;
        if (offset + size > (size_t)length) return 1;
        const unsigned char *data = response + offset;
        printf("CAP TLV 0x%02x size %u:", type, size);
        for (unsigned int i = 0; i < size; i++) printf(" %02x", data[i]);
        putchar('\n');
        if (type == 2 && size == 4) {
            printf("QMI result %u, error %u\n", le16(data), le16(data + 2));
            if (le16(data)) return 1;
            result_seen = 1;
        }
        if (type == 0x10 && size == 8)
            printf("Chip ID 0x%x, family 0x%x\n", le32(data), le32(data + 4));
        if (type == 0x11 && size == 4) printf("Board ID 0x%x\n", le32(data));
        if (type == 0x12 && size == 4) printf("SoC ID 0x%x\n", le32(data));
        offset += size;
    }
    if (!result_seen) return 1;
    puts("WLFW_CAPABILITY_QUERY_PASS");
    return 0;
}
