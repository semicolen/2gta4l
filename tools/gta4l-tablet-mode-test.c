/* Report the fixed tablet form factor through the standard input switch API. */
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static volatile sig_atomic_t running=1;
static void stop(int sig) { (void)sig; running=0; }
int main(void)
{
    if (geteuid()!=0) { fputs("Root is required for the tablet-mode switch\n",stderr); return 1; }
    sigset_t blocked,previous;
    sigemptyset(&blocked);sigaddset(&blocked,SIGTERM);sigaddset(&blocked,SIGINT);
    if(sigprocmask(SIG_BLOCK,&blocked,&previous)<0){perror("block signals");return 1;}
    signal(SIGTERM,stop);signal(SIGINT,stop);
    int fd=open("/dev/uinput",O_WRONLY|O_NONBLOCK|O_CLOEXEC);
    if(fd<0){perror("open uinput");return 1;}
    if(ioctl(fd,UI_SET_EVBIT,EV_SW)<0||ioctl(fd,UI_SET_SWBIT,SW_TABLET_MODE)<0){perror("configure switch");close(fd);return 1;}
    struct uinput_user_dev dev={0};
    snprintf(dev.name,sizeof(dev.name),"gta4l-fixed-tablet-mode");dev.id.bustype=BUS_VIRTUAL;
    if(write(fd,&dev,sizeof(dev))!=(ssize_t)sizeof(dev)||ioctl(fd,UI_DEV_CREATE)<0){perror("create switch");close(fd);return 1;}
    struct input_event event[2]={0};
    event[0].type=EV_SW;event[0].code=SW_TABLET_MODE;event[0].value=1;
    event[1].type=EV_SYN;event[1].code=SYN_REPORT;
    if(write(fd,event,sizeof(event))!=(ssize_t)sizeof(event)){perror("set tablet mode");ioctl(fd,UI_DEV_DESTROY);close(fd);return 1;}
    puts("FIXED_TABLET_MODE_SWITCH_ON");fflush(stdout);
    while(running) sigsuspend(&previous);
    ioctl(fd,UI_DEV_DESTROY);close(fd);puts("FIXED_TABLET_MODE_SWITCH_CLOSED");return 0;
}
