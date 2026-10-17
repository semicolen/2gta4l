/* SPDX-License-Identifier: MIT
 * On-demand user-session PipeWire source for the SM-T505 camera broker.
 * Stream API follows PipeWire's MIT-licensed video-src example by Wim Taymans.
 */
#define _GNU_SOURCE
#include <pipewire/pipewire.h>
#include <spa/param/video/format-utils.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>

#define WIDTH 640
#define HEIGHT 480
#define RGB_BYTES (WIDTH * HEIGHT * 3)
#define FRAME_BYTES (WIDTH * HEIGHT * 4)
#define STRIDE (WIDTH * 4)

struct source {
    struct pw_main_loop *loop;
    struct pw_context *context;
    struct pw_core *core;
    struct pw_stream *stream;
    struct spa_hook listener;
    struct spa_source *timer;
    pthread_t worker;
    pthread_mutex_t lock;
    pthread_cond_t changed;
    bool wanted, quitting, have_frame, test_pattern;
    uint8_t *pixels;
    uint64_t frame_time;
    uint32_t sequence;
    const char *camera;
    struct wl_display *display;
    struct wl_registry *registry;
    struct wl_output *output;
    struct spa_source *display_io;
    int output_transform;
    uint32_t video_transform;
};

static void output_geometry(void *arg, struct wl_output *output, int32_t x, int32_t y,
    int32_t width, int32_t height, int32_t subpixel, const char *make,
    const char *model, int32_t transform)
{
    (void)output; (void)x; (void)y; (void)width; (void)height;
    (void)subpixel; (void)make; (void)model;
    struct source *s = arg;
    if (transform < WL_OUTPUT_TRANSFORM_NORMAL || transform > WL_OUTPUT_TRANSFORM_270) return;
    unsigned angle = (180 + 90 * (unsigned)transform) % 360;
    unsigned rotation = !strcmp(s->camera,"rear") ? (90 + angle) % 360 : (630 - angle) % 360;
    /* The standard source is unmirrored; camera apps mirror front previews. */
    pthread_mutex_lock(&s->lock);
    s->output_transform = transform;
    s->video_transform = s->test_pattern ? SPA_META_TRANSFORMATION_None : rotation / 90;
    pthread_mutex_unlock(&s->lock);
}

static void output_mode(void *a, struct wl_output *o, uint32_t f, int32_t w, int32_t h, int32_t r)
{ (void)a; (void)o; (void)f; (void)w; (void)h; (void)r; }
static void output_done(void *a, struct wl_output *o) { (void)a; (void)o; }
static void output_scale(void *a, struct wl_output *o, int32_t n) { (void)a; (void)o; (void)n; }
static const struct wl_output_listener output_events = {
    .geometry = output_geometry, .mode = output_mode, .done = output_done, .scale = output_scale
};

static void registry_added(void *arg, struct wl_registry *registry, uint32_t name,
    const char *interface, uint32_t version)
{
    struct source *s = arg;
    /* SM-T505 has one internal output. Bind v2 to receive geometry updates. */
    if (!s->output && !strcmp(interface, wl_output_interface.name)) {
        s->output = wl_registry_bind(registry, name, &wl_output_interface, version < 2 ? version : 2);
        wl_output_add_listener(s->output, &output_events, s);
    }
}
static void registry_removed(void *a, struct wl_registry *r, uint32_t n) { (void)a; (void)r; (void)n; }
static const struct wl_registry_listener registry_events = { .global = registry_added, .global_remove = registry_removed };

static void display_ready(void *arg, int fd, uint32_t mask)
{
    (void)fd;
    struct source *s = arg;
    if ((mask & (SPA_IO_ERR | SPA_IO_HUP)) || wl_display_dispatch(s->display) < 0) {
        pw_main_loop_quit(s->loop); return;
    }
    wl_display_flush(s->display);
}

static uint64_t now_ns(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (uint64_t)t.tv_sec * 1000000000ULL + t.tv_nsec;
}

static bool requested(struct source *s)
{
    bool result;
    pthread_mutex_lock(&s->lock);
    result = s->wanted && !s->quitting;
    pthread_mutex_unlock(&s->lock);
    return result;
}

static void pause_worker(struct source *s, unsigned milliseconds)
{
    struct timespec deadline;
    clock_gettime(CLOCK_REALTIME, &deadline);
    deadline.tv_nsec += (long)milliseconds * 1000000;
    deadline.tv_sec += deadline.tv_nsec / 1000000000;
    deadline.tv_nsec %= 1000000000;
    pthread_mutex_lock(&s->lock);
    if (!s->quitting)
        pthread_cond_timedwait(&s->changed, &s->lock, &deadline);
    pthread_mutex_unlock(&s->lock);
}

static int command(struct source *s, int fd, const char *text, char *reply, size_t size)
{
    size_t sent = 0, received = 0;
    uint64_t deadline = now_ns() + 1500000000ULL;
    while (sent < strlen(text)) {
        ssize_t count = send(fd, text + sent, strlen(text) - sent, MSG_NOSIGNAL);
        if (count > 0) sent += (size_t)count;
        else if (count < 0 && errno == EINTR) continue;
        else return -1;
    }
    while (requested(s) && now_ns() < deadline && received + 1 < size) {
        struct pollfd item = { .fd = fd, .events = POLLIN };
        int ready = poll(&item, 1, 100);
        if (ready < 0 && errno == EINTR) continue;
        if (ready < 0) return -1;
        if (!ready) continue;
        ssize_t count = recv(fd, reply + received, size - received - 1, 0);
        if (count <= 0) return -1;
        received += (size_t)count;
        reply[received] = 0;
        if (strchr(reply, '\n')) return strstr(reply, "\"error\"") ? -1 : 0;
    }
    return -1;
}

static int connect_camera(struct source *s)
{
    struct sockaddr_un address = { .sun_family = AF_UNIX };
    struct ucred owner;
    socklen_t length = sizeof(owner);
    char reply[1024], request[16];
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
    if (fd < 0) return -1;
    snprintf(address.sun_path, sizeof(address.sun_path), "/run/gta4l-camera/control.sock");
    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) < 0 ||
        getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &owner, &length) < 0 || owner.uid != 0)
        goto fail;
    /* A timed-out discovery connection must never queue a capture command. */
    if (command(s, fd, "status\n", reply, sizeof(reply)) < 0 || !requested(s)) goto fail;
    snprintf(request, sizeof(request), "%s\n", s->camera);
    if (command(s, fd, request, reply, sizeof(reply)) < 0 ||
        !strstr(reply, "\"running\": true")) goto fail;
    fprintf(stderr, "%s: camera acquired\n", s->camera);
    return fd;
fail:
    close(fd);
    return -1;
}

static bool read_frame(uint8_t *rgb, struct stat *identity)
{
    static const char header[] = "P6\n640 480\n255\n";
    char actual[sizeof(header) - 1];
    struct stat info;
    int fd = open("/run/gta4l-camera/frames/frame.ppm", O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return false;
    bool result = false;
    if (fstat(fd, &info) < 0 || !S_ISREG(info.st_mode) || info.st_uid != 0 ||
        info.st_size != (off_t)(sizeof(actual) + RGB_BYTES) ||
        (info.st_ino == identity->st_ino && info.st_mtim.tv_sec == identity->st_mtim.tv_sec &&
         info.st_mtim.tv_nsec == identity->st_mtim.tv_nsec)) goto out;
    if (read(fd, actual, sizeof(actual)) != (ssize_t)sizeof(actual) ||
        memcmp(actual, header, sizeof(actual))) goto out;
    size_t got = 0;
    while (got < RGB_BYTES) {
        ssize_t count = read(fd, rgb + got, RGB_BYTES - got);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) goto out;
        got += (size_t)count;
    }
    *identity = info;
    result = true;
out:
    close(fd);
    return result;
}

static void *capture_worker(void *arg)
{
    struct source *s = arg;
    uint8_t *rgb = malloc(RGB_BYTES), *frame = malloc(FRAME_BYTES);
    int fd = -1;
    unsigned tick = 0;
    uint64_t last_status = 0;
    struct stat identity = { 0 };
    if (!rgb || !frame) { free(rgb); free(frame); return NULL; }
    for (;;) {
        pthread_mutex_lock(&s->lock);
        bool quit = s->quitting;
        pthread_mutex_unlock(&s->lock);
        if (quit) break;
        if (!requested(s)) {
            if (fd >= 0) { close(fd); fd = -1; fprintf(stderr, "%s: camera released\n", s->camera); }
            memset(&identity, 0, sizeof(identity));
            pthread_mutex_lock(&s->lock);
            while (!s->wanted && !s->quitting)
                pthread_cond_wait(&s->changed, &s->lock);
            pthread_mutex_unlock(&s->lock);
            continue;
        }
        bool fresh = false;
        if (s->test_pattern) {
            for (unsigned y = 0; y < HEIGHT; y++) for (unsigned x = 0; x < WIDTH; x++) {
                size_t n = (y * WIDTH + x) * 4;
                frame[n] = x < WIDTH / 3 ? 220 : 0;
                frame[n + 1] = x >= WIDTH / 3 && x < 2 * WIDTH / 3 ? 220 : 0;
                frame[n + 2] = x >= 2 * WIDTH / 3 ? 220 : 0;
                frame[n + 3] = 255;
                if (x >= tick % (WIDTH - 30) && x < tick % (WIDTH - 30) + 30 && y < 30)
                    frame[n] = frame[n + 1] = frame[n + 2] = 255;
            }
            tick += 8; fresh = true;
        } else {
            if (fd < 0) {
                fd = connect_camera(s);
                if (fd < 0) { pause_worker(s, 500); continue; }
                last_status = now_ns();
            }
            if (now_ns() - last_status > 1000000000ULL) {
                char reply[1024];
                if (command(s, fd, "status\n", reply, sizeof(reply)) < 0 ||
                    !strstr(reply, "\"running\": true")) {
                    close(fd); fd = -1; pause_worker(s, 500); continue;
                }
                last_status = now_ns();
            }
            if (read_frame(rgb, &identity)) {
                for (size_t i = 0; i < WIDTH * HEIGHT; i++) {
                    frame[4*i] = rgb[3*i]; frame[4*i+1] = rgb[3*i+1];
                    frame[4*i+2] = rgb[3*i+2]; frame[4*i+3] = 255;
                }
                fresh = true;
            }
        }
        if (fresh) {
            pthread_mutex_lock(&s->lock);
            if (s->wanted && !s->quitting) {
                memcpy(s->pixels, frame, FRAME_BYTES);
                s->have_frame = true; s->frame_time = now_ns();
            }
            pthread_mutex_unlock(&s->lock);
        }
        pause_worker(s, 75);
    }
    if (fd >= 0) close(fd);
    free(rgb); free(frame);
    return NULL;
}

static void process_frame(void *arg)
{
    struct source *s = arg;
    struct pw_buffer *buffer = pw_stream_dequeue_buffer(s->stream);
    if (!buffer) return;
    struct spa_buffer *spa = buffer->buffer;
    if (!spa->n_datas || !spa->datas[0].data || spa->datas[0].maxsize < FRAME_BYTES) {
        if (spa->n_datas) spa->datas[0].chunk->size = 0;
        pw_stream_queue_buffer(s->stream, buffer); return;
    }
    pthread_mutex_lock(&s->lock);
    uint32_t transformation = s->video_transform;
    if (s->have_frame && now_ns() - s->frame_time < 2000000000ULL)
        memcpy(spa->datas[0].data, s->pixels, FRAME_BYTES);
    else memset(spa->datas[0].data, 0, FRAME_BYTES);
    pthread_mutex_unlock(&s->lock);
    struct spa_meta_header *header = spa_buffer_find_meta_data(spa, SPA_META_Header, sizeof(*header));
    if (header) { header->pts = pw_stream_get_nsec(s->stream); header->seq = s->sequence++; header->flags = 0; header->dts_offset = 0; }
    struct spa_meta_videotransform *transform = spa_buffer_find_meta_data(spa, SPA_META_VideoTransform, sizeof(*transform));
    if (transform) transform->transform = transformation;
    spa->datas[0].chunk->offset = 0; spa->datas[0].chunk->size = FRAME_BYTES; spa->datas[0].chunk->stride = STRIDE;
    pw_stream_queue_buffer(s->stream, buffer);
}

static void tick(void *arg, uint64_t expirations)
{
    (void)expirations;
    struct source *s = arg;
    pw_stream_trigger_process(s->stream);
}

static void state_changed(void *arg, enum pw_stream_state old, enum pw_stream_state state, const char *error)
{
    (void)old;
    struct source *s = arg;
    fprintf(stderr, "%s: PipeWire %s%s%s\n", s->camera, pw_stream_state_as_string(state), error ? ": " : "", error ? error : "");
    pthread_mutex_lock(&s->lock);
    s->wanted = state == PW_STREAM_STATE_STREAMING;
    s->have_frame = false;
    memset(s->pixels, 0, FRAME_BYTES);
    pthread_cond_signal(&s->changed);
    pthread_mutex_unlock(&s->lock);
    struct timespec start = { .tv_nsec = 1 }, interval = { .tv_nsec = 100000000 };
    pw_loop_update_timer(pw_main_loop_get_loop(s->loop), s->timer,
                         s->wanted ? &start : NULL, s->wanted ? &interval : NULL, false);
    if (state == PW_STREAM_STATE_ERROR || state == PW_STREAM_STATE_UNCONNECTED) pw_main_loop_quit(s->loop);
}

static void format_changed(void *arg, uint32_t id, const struct spa_pod *param)
{
    struct source *s = arg;
    struct spa_video_info_raw format = { 0 };
    if (id != SPA_PARAM_Format || !param) return;
    if (spa_format_video_raw_parse(param, &format) < 0 || format.format != SPA_VIDEO_FORMAT_RGBx ||
        format.size.width != WIDTH || format.size.height != HEIGHT) {
        pw_stream_set_error(s->stream, -EINVAL, "Unsupported camera format"); return;
    }
    uint8_t memory[512];
    struct spa_pod_builder builder = SPA_POD_BUILDER_INIT(memory, sizeof(memory));
    const struct spa_pod *params[3];
    params[0] = spa_pod_builder_add_object(&builder, SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers,
        SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(4, 2, 8), SPA_PARAM_BUFFERS_blocks, SPA_POD_Int(1),
        SPA_PARAM_BUFFERS_size, SPA_POD_Int(FRAME_BYTES), SPA_PARAM_BUFFERS_stride, SPA_POD_Int(STRIDE));
    params[1] = spa_pod_builder_add_object(&builder, SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta,
        SPA_PARAM_META_type, SPA_POD_Id(SPA_META_Header), SPA_PARAM_META_size, SPA_POD_Int(sizeof(struct spa_meta_header)));
    params[2] = spa_pod_builder_add_object(&builder, SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta,
        SPA_PARAM_META_type, SPA_POD_Id(SPA_META_VideoTransform), SPA_PARAM_META_size, SPA_POD_Int(sizeof(struct spa_meta_videotransform)));
    pw_stream_update_params(s->stream, params, 3);
}

static void quit(void *arg, int signal_number)
{
    (void)signal_number;
    pw_main_loop_quit(((struct source *)arg)->loop);
}

int main(int argc, char **argv)
{
    if (argc < 2 || argc > 3 || (strcmp(argv[1], "rear") && strcmp(argv[1], "front")) ||
        (argc == 3 && strcmp(argv[2], "--test-pattern"))) {
        fprintf(stderr, "usage: gta4l-camera-pipewire rear|front [--test-pattern]\n"); return 2;
    }
    struct source s = { .camera = argv[1], .test_pattern = argc == 3,
                       .lock = PTHREAD_MUTEX_INITIALIZER, .changed = PTHREAD_COND_INITIALIZER };
    s.pixels = calloc(1, FRAME_BYTES);
    if (!s.pixels) return 1;
    pw_init(&argc, &argv);
    s.loop = pw_main_loop_new(NULL);
    s.context = pw_context_new(pw_main_loop_get_loop(s.loop), NULL, 0);
    s.core = pw_context_connect(s.context, NULL, 0);
    if (!s.core) { fprintf(stderr, "PipeWire connection failed: %s\n", strerror(errno)); return 1; }
    s.timer = pw_loop_add_timer(pw_main_loop_get_loop(s.loop), tick, &s);
    s.video_transform = s.test_pattern ? SPA_META_TRANSFORMATION_None :
        (!strcmp(s.camera,"rear") ? SPA_META_TRANSFORMATION_90 : SPA_META_TRANSFORMATION_270);
    if (getenv("WAYLAND_DISPLAY") && (s.display = wl_display_connect(NULL))) {
        s.registry = wl_display_get_registry(s.display);
        wl_registry_add_listener(s.registry, &registry_events, &s);
        if (wl_display_roundtrip(s.display) < 0 || wl_display_roundtrip(s.display) < 0) return 1;
        s.display_io = pw_loop_add_io(pw_main_loop_get_loop(s.loop), wl_display_get_fd(s.display),
            SPA_IO_IN | SPA_IO_ERR | SPA_IO_HUP, false, display_ready, &s);
    }
    pw_loop_add_signal(pw_main_loop_get_loop(s.loop), SIGTERM, quit, &s);
    pw_loop_add_signal(pw_main_loop_get_loop(s.loop), SIGINT, quit, &s);
    char node[80]; snprintf(node, sizeof(node), "gta4l.camera.%s", s.camera);
    s.stream = pw_stream_new(s.core, node, pw_properties_new(
        PW_KEY_MEDIA_CLASS, "Video/Source", PW_KEY_MEDIA_TYPE, "Video", PW_KEY_MEDIA_ROLE, "Camera",
        PW_KEY_NODE_NAME, node, PW_KEY_NODE_DESCRIPTION, !strcmp(s.camera,"rear") ? "Galaxy Tab A7 Rear Camera" : "Galaxy Tab A7 Front Camera",
        "api.libcamera.location", !strcmp(s.camera,"rear") ? "back" : "front",
        PW_KEY_NODE_SUPPORTS_REQUEST, "true", "node.pause-on-idle", "true", "node.virtual", "true", NULL));
    static const struct pw_stream_events events = { PW_VERSION_STREAM_EVENTS,
        .state_changed = state_changed, .param_changed = format_changed, .process = process_frame };
    pw_stream_add_listener(s.stream, &s.listener, &events, &s);
    uint8_t memory[512]; struct spa_pod_builder builder = SPA_POD_BUILDER_INIT(memory, sizeof(memory));
    const struct spa_pod *format = spa_pod_builder_add_object(&builder, SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat,
        SPA_FORMAT_mediaType, SPA_POD_Id(SPA_MEDIA_TYPE_video), SPA_FORMAT_mediaSubtype, SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw),
        SPA_FORMAT_VIDEO_format, SPA_POD_Id(SPA_VIDEO_FORMAT_RGBx), SPA_FORMAT_VIDEO_size, SPA_POD_Rectangle(&SPA_RECTANGLE(WIDTH,HEIGHT)),
        SPA_FORMAT_VIDEO_framerate, SPA_POD_Fraction(&SPA_FRACTION(10,1)));
    if (pthread_create(&s.worker, NULL, capture_worker, &s)) return 1;
    int result = pw_stream_connect(s.stream, PW_DIRECTION_OUTPUT, PW_ID_ANY,
        PW_STREAM_FLAG_DRIVER | PW_STREAM_FLAG_MAP_BUFFERS, &format, 1);
    if (result >= 0) pw_main_loop_run(s.loop);
    pthread_mutex_lock(&s.lock); s.quitting = true; s.wanted = false; pthread_cond_signal(&s.changed); pthread_mutex_unlock(&s.lock);
    pthread_join(s.worker, NULL);
    if (s.display_io) pw_loop_destroy_source(pw_main_loop_get_loop(s.loop), s.display_io);
    if (s.output) wl_output_destroy(s.output);
    if (s.registry) wl_registry_destroy(s.registry);
    if (s.display) wl_display_disconnect(s.display);
    pw_stream_destroy(s.stream); pw_core_disconnect(s.core); pw_context_destroy(s.context);
    pw_main_loop_destroy(s.loop); pw_deinit(); free(s.pixels);
    return result < 0 ? 1 : 0;
}
