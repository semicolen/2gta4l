#define _GNU_SOURCE
#include <assert.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "translate.h"

/* Exercise the three paths the SM-T505 modem actually requested, without
 * a modem, QRTR socket, or /sys/class/remoteproc. */
int main(void)
{
    char directory[] = "/tmp/gta4l-tqftp-test-XXXXXX";
    char fixture[256];
    const char *prefixes[] = {
        "/readonly/vendor/firmware_mnt/image/",
        "/readonly/vendor/firmware/",
        "/readonly/firmware/image/",
    };
    assert(mkdtemp(directory));
    assert(setenv("TQFTPSERV_FW_DIR", directory, 1) == 0);
    snprintf(fixture, sizeof(fixture), "%s/wlanmdsp.mbn", directory);
    int fd = open(fixture, O_CREAT | O_EXCL | O_WRONLY, 0600);
    assert(fd >= 0);
    assert(write(fd, "test-firmware", 13) == 13);
    close(fd);
    for (unsigned int i = 0; i < sizeof(prefixes) / sizeof(prefixes[0]); i++) {
        char request[256], data[16] = {0};
        snprintf(request, sizeof(request), "%swlanmdsp.mbn", prefixes[i]);
        fd = translate_open(request, O_RDONLY);
        assert(fd >= 0);
        assert(read(fd, data, sizeof(data)) == 13);
        assert(strcmp(data, "test-firmware") == 0);
        assert(write(fd, "x", 1) == -1);
        close(fd);
    }
    assert(translate_open("/readonly/firmware/image/missing.mbn", O_RDONLY) == -1);
    assert(translate_open("/readonly/firmware/image/../outside", O_RDONLY) == -1);
    assert(translate_open("/readonly/firmware/image//etc/passwd", O_RDONLY) == -1);
    assert(translate_open("/invalid/wlanmdsp.mbn", O_RDONLY) == -1);
    assert(unlink(fixture) == 0);
    assert(rmdir(directory) == 0);
    puts("PASS: three stock firmware request paths, read-only access and invalid-path rejection");
    return 0;
}
