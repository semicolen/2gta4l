/* SPDX-License-Identifier: MIT */
#define _POSIX_C_SOURCE 200809L
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

/* Downstream subsystem_restart.c boots firmware on open and stops it on close. */
int main(int argc, char **argv)
{
    sigset_t signals;
    struct stat info;
    int fd, received;

    if (argc != 2) {
        fprintf(stderr, "Usage: %s /dev/subsys_modem\n", argv[0]);
        return 2;
    }
    if (stat(argv[1], &info) || !S_ISCHR(info.st_mode)) {
        fprintf(stderr, "Subsystem character device unavailable: %s\n", argv[1]);
        return 1;
    }
    sigemptyset(&signals);
    sigaddset(&signals, SIGTERM);
    sigaddset(&signals, SIGINT);
    if (sigprocmask(SIG_BLOCK, &signals, NULL)) {
        perror("sigprocmask");
        return 1;
    }
    fd = open(argv[1], O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        perror(argv[1]);
        return 1;
    }
    fprintf(stderr, "Holding subsystem active: %s\n", argv[1]);
    if (sigwait(&signals, &received)) {
        close(fd);
        return 1;
    }
    close(fd);
    return 0;
}
