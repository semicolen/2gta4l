#define _POSIX_C_SOURCE 200809L
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

/* Read-only kernel log transport, bound exclusively to the tablet USB IP.
 * No PTY or shell child is used, so getty cleanup cannot close the stream. */
static int send_all(int fd, const char *data, size_t size) {
    while (size) {
        ssize_t done = send(fd, data, size, MSG_NOSIGNAL);
        if (done < 0 && errno == EINTR) continue;
        if (done <= 0) return -1;
        data += done;
        size -= (size_t)done;
    }
    return 0;
}

static void serve(int input, int client) {
    /* Keep the descriptor opened before switch_root. The daemon's old root
     * loses /dev when the mount is moved, so reopening by pathname would fail. */
    if (lseek(input, 0, SEEK_SET) < 0) { perror("rewind kmsg"); return; }
    struct pollfd watched[2] = {
        {.fd = input, .events = POLLIN},
        {.fd = client, .events = POLLIN}
    };
    char data[8192];
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    time_t heartbeat = now.tv_sec;
    for (;;) {
        int ready = poll(watched, 2, 500);
        if (ready < 0 && errno == EINTR) continue;
        if (ready < 0 || watched[1].revents) break;
        if (watched[0].revents & POLLIN) {
            for (int i = 0; i < 64; i++) {
                ssize_t count = read(input, data, sizeof data);
                if (count < 0 && errno == EPIPE) {
                    const char lost[] = "GTA4L_STREAM: kernel ring overrun\n";
                    if (send_all(client, lost, sizeof lost - 1)) goto done;
                    continue;
                }
                if (count < 0 && (errno == EAGAIN || errno == EINTR)) break;
                if (count <= 0 || send_all(client, data, (size_t)count)) goto done;
            }
        }
        clock_gettime(CLOCK_MONOTONIC, &now);
        if (now.tv_sec - heartbeat >= 2) {
            int count = snprintf(data, sizeof data, "GTA4L_STREAM: heartbeat uptime=%ld\n", (long)now.tv_sec);
            if (send_all(client, data, (size_t)count)) break;
            heartbeat = now.tv_sec;
        }
    }
done:
    return;
}

int main(void) {
    /* A background process launched by the debug shell has no controlling TTY. */
    (void)setsid();
    signal(SIGHUP, SIG_IGN);
    signal(SIGPIPE, SIG_IGN);
    int input = open("/dev/kmsg", O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    struct stat info;
    if (input < 0 || fstat(input, &info) || !S_ISCHR(info.st_mode)) {
        fprintf(stderr, "Kernel log input must be an accessible character device\n");
        return 1;
    }
    int server = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (server < 0) { perror("socket"); return 1; }
    int one = 1;
    setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
    struct sockaddr_in address = {.sin_family = AF_INET, .sin_port = htons(2425)};
    if (inet_pton(AF_INET, "172.16.42.1", &address.sin_addr) != 1 ||
        bind(server, (struct sockaddr *)&address, sizeof address) || listen(server, 1)) {
        perror("bind/listen USB log port");
        close(server);
        return 1;
    }
    for (;;) {
        int client = accept(server, NULL, NULL);
        if (client < 0 && errno == EINTR) continue;
        if (client < 0) { perror("accept"); break; }
        serve(input, client);
        close(client);
    }
    close(server);
    close(input);
    return 1;
}
