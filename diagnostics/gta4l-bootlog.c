#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

static volatile sig_atomic_t stopping;
static void stop(int sig) { (void)sig; stopping = 1; }
static int write_all(int fd, const char *data, ssize_t size) {
    while (size > 0) {
        ssize_t done = write(fd, data, (size_t)size);
        if (done < 0 && errno == EINTR) continue;
        if (done <= 0) return -1;
        data += done;
        size -= done;
    }
    return 0;
}
int main(int argc, char **argv) {
    if (argc != 3) return 2;
    int input = open(argv[1], O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    struct stat info;
    if (input < 0 || fstat(input, &info) || !S_ISCHR(info.st_mode)) {
        fprintf(stderr, "Kernel log input must be an accessible character device\n");
        return 2;
    }
    int output = open(argv[2], O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (output < 0) { perror("open log output"); close(input); return 2; }
    struct sigaction action = {0};
    action.sa_handler = stop;
    sigemptyset(&action.sa_mask);
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGINT, &action, NULL);
    struct pollfd watched = {.fd = input, .events = POLLIN};
    char buffer[8192];
    int result = 0;
    while (!stopping) {
        int ready = poll(&watched, 1, 250);
        if (ready < 0 && errno == EINTR) continue;
        if (ready < 0) { perror("poll"); result = 1; break; }
        if (!ready) continue;
        int dirty = 0;
        /* Bound each batch so an active producer cannot delay fsync forever. */
        for (int i = 0; i < 64 && !stopping; i++) {
            ssize_t size = read(input, buffer, sizeof buffer);
            if (size < 0 && errno == EPIPE) {
                static const char lost[] = "KMSG_OVERRUN: some kernel records were lost\n";
                if (write_all(output, lost, sizeof lost - 1)) { result = 1; stopping = 1; }
                dirty = 1;
                continue;
            }
            if (size < 0 && (errno == EAGAIN || errno == EINTR)) break;
            if (size <= 0) { result = 1; stopping = 1; break; }
            if (write_all(output, buffer, size)) { perror("write"); result = 1; stopping = 1; break; }
            dirty = 1;
        }
        if (dirty && fdatasync(output)) { perror("fdatasync"); result = 1; break; }
    }
    if (fdatasync(output)) result = 1;
    close(output);
    close(input);
    return result;
}
