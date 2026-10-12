/* Minimal Android 12/Bionic camera module enumeration diagnostic.
 * ABI references: official android-12.0.0_r1 hardware.h, camera_common.h,
 * libc_init_common.h and crtbegin.c (recorded by fetch-camera-reference.py).
 * Capture diagnostics issue a bounded HAL3 request with a gralloc1-owned buffer.
 */
#include <stddef.h>
#include <stdint.h>
#include <stdarg.h>

extern int printf(const char *, ...);
extern int puts(const char *);
extern int fflush(void *);
extern int strcmp(const char *, const char *);
extern void *dlopen(const char *, int);
extern void *dlsym(void *, const char *);
extern char *dlerror(void);
extern int vsnprintf(char *, size_t, const char *, va_list);
extern void (*signal(int,void (*)(int)))(int);
static volatile int stop_requested;
static void request_stop(int number) { (void)number; stop_requested=1; }

/* Exported only by this isolated test process; no system logger is replaced. */
int __android_log_print(int priority, const char *tag, const char *format, ...) {
    char text[2048];
    va_list args;
    va_start(args, format);
    int count = vsnprintf(text, sizeof(text), format, args);
    va_end(args);
    if (priority >= 5) {
        printf("Android log [%s]: %s\n", tag ? tag : "(none)", text);
        fflush(0);
    }
    return count;
}
int __android_log_write(int priority, const char *tag, const char *text) {
    return __android_log_print(priority, tag, "%s", text ? text : "(none)");
}

struct hw_module {
    uint32_t tag;
    uint16_t module_api_version, hal_api_version;
    const char *id, *name, *author;
    void *methods, *dso;
    uint64_t reserved[25];
};
struct camera_info {
    int facing, orientation;
    uint32_t device_version;
    const void *static_camera_characteristics;
    int resource_cost;
    char **conflicting_devices;
    size_t conflicting_devices_length;
};
struct metadata_entry {
    size_t index;
    uint32_t tag;
    uint8_t type;
    size_t count;
    union { const int32_t *i32; const void *data; } value;
};
static int stream_capabilities(int id,const void *metadata) {
    void *library=dlopen("libcamera_metadata.so",2);
    if (!library) { printf("METADATA_LOAD_ERROR: %s\n",dlerror()); return 31; }
    int (*find)(const void *,uint32_t,struct metadata_entry *)=dlsym(library,"find_camera_metadata_ro_entry");
    if (!find) return 32;
    struct metadata_entry entry={0};
    /* android-12.0.0_r1 camera_metadata_tags.h: SCALER section 13,
     * AVAILABLE_STREAM_CONFIGURATIONS is offset 10. Four int32s per entry. */
    int rc=find(metadata,0x000d000a,&entry);
    if (rc || entry.type!=1 || entry.count%4 || entry.count>16384 || !entry.value.i32) return 33;
    for (size_t index=0;index<entry.count;index+=4) {
        const int32_t *config=entry.value.i32+index;
        printf("CAMERA_SUPPORTED_STREAM id=%d format=0x%x width=%d height=%d direction=%d\n",
               id,config[0],config[1],config[2],config[3]);
    }
    if (!find(metadata,0x00070008,&entry) && entry.type==1 && entry.count==1)
        printf("CAMERA_JPEG_MAX_BYTES id=%d value=%d\n",id,entry.value.i32[0]);
    fflush(0);
    return 0;
}
static int full_capture_size(const void *metadata,uint32_t *width,uint32_t *height) {
    void *library=dlopen("libcamera_metadata.so",2);
    if (!library) return 31;
    int (*find)(const void *,uint32_t,struct metadata_entry *)=dlsym(library,"find_camera_metadata_ro_entry");
    struct metadata_entry entry={0};
    if (!find || find(metadata,0x000d000a,&entry) || entry.type!=1 || entry.count%4 || entry.count>16384 || !entry.value.i32) return 33;
    uint32_t best_width=0,best_height=0;
    for (size_t index=0;index<entry.count;index+=4) {
        const int32_t *c=entry.value.i32+index;
        if (c[0]!=0x23 || c[3]!=0 || c[1]<=0 || c[2]<=0 || c[1]>4096 || c[2]>4096 || (c[1]%2) || (c[2]%2)) continue;
        if ((uint32_t)(c[1]*c[2])>best_width*best_height) { best_width=(uint32_t)c[1]; best_height=(uint32_t)c[2]; }
    }
    if (!best_width || !best_height) return 34;
    *width=best_width; *height=best_height;
    return 0;
}
struct hw_device {
    uint32_t tag, version;
    struct hw_module *module;
    uint64_t reserved[12];
    int (*close)(struct hw_device *);
};
struct hw_module_methods {
    int (*open)(const struct hw_module *, const char *, struct hw_device **);
};
#include "camera-buffer.h"
struct camera3_callbacks {
    void (*result)(const struct camera3_callbacks *, const void *);
    void (*notify)(const struct camera3_callbacks *, const void *);
    void *request_stream_buffers, *return_stream_buffers;
};
struct camera3_device;
struct camera3_stream {
    int stream_type;
    uint32_t width, height;
    int format;
    uint32_t usage, max_buffers;
    void *priv;
    int data_space, rotation;
    const char *physical_camera_id;
    void *reserved[6];
};
struct camera3_configuration {
    uint32_t num_streams;
    struct camera3_stream **streams;
    uint32_t operation_mode;
    const void *session_parameters;
};
struct camera3_stream_buffer {
    struct camera3_stream *stream;
    buffer_handle *buffer;
    int status, acquire_fence, release_fence;
};
struct camera3_request {
    uint32_t frame_number;
    const void *settings;
    struct camera3_stream_buffer *input_buffer;
    uint32_t num_output_buffers;
    const struct camera3_stream_buffer *output_buffers;
    uint32_t num_physcam_settings;
    const char **physcam_id;
    const void **physcam_settings;
};
struct camera3_result {
    uint32_t frame_number;
    const void *result;
    uint32_t num_output_buffers;
    const struct camera3_stream_buffer *output_buffers;
    const struct camera3_stream_buffer *input_buffer;
    uint32_t partial_result, num_physcam_metadata;
    const char **physcam_ids;
    const void **physcam_metadata;
};
struct camera3_message {
    int type;
    union {
        struct { uint32_t frame; struct camera3_stream *stream; int code; } error;
        struct { uint32_t frame; uint64_t timestamp; } shutter;
        uint8_t generic[32];
    } message;
};
struct camera3_ops {
    int (*initialize)(const struct camera3_device *, const struct camera3_callbacks *);
    int (*configure)(const struct camera3_device *, struct camera3_configuration *);
    void *register_buffers;
    const void *(*default_settings)(const struct camera3_device *, int);
    int (*capture)(const struct camera3_device *, struct camera3_request *);
    void *vendor_tags, *dump;
    int (*flush)(const struct camera3_device *);
};
struct camera3_device {
    struct hw_device common;
    const struct camera3_ops *ops;
    void *priv;
};
static buffer_handle expected_buffer;
static uint32_t expected_frame;
static int buffer_returned, buffer_status, buffer_fence;
static void capture_result(const struct camera3_callbacks *cb, const void *result) {
    (void)cb;
    const struct camera3_result *r=result;
    printf("CAMERA_RESULT frame=%u buffers=%u partial=%u\n",r->frame_number,r->num_output_buffers,r->partial_result);
    if (r->num_output_buffers && r->output_buffers && !__atomic_load_n(&buffer_returned,__ATOMIC_ACQUIRE)) {
        const struct camera3_stream_buffer *b=r->output_buffers;
        if (r->frame_number==expected_frame && r->num_output_buffers==1 && b->buffer && *b->buffer==expected_buffer) {
            buffer_status=b->status;
            buffer_fence=b->release_fence;
            __atomic_store_n(&buffer_returned,1,__ATOMIC_RELEASE);
        }
    }
    fflush(0);
}
static void camera_notify(const struct camera3_callbacks *cb, const void *message) {
    (void)cb;
    const struct camera3_message *m=message;
    if (m->type==1) printf("CAMERA_ERROR frame=%u code=%d\n",m->message.error.frame,m->message.error.code);
    else if (m->type==2) printf("CAMERA_SHUTTER frame=%u\n",m->message.shutter.frame);
    fflush(0);
}
static const struct camera3_callbacks callbacks = {.result=capture_result, .notify=camera_notify};
/* Matching T505XXS8CXG1 camera.qcom.so (SHA256 3dfa3c004119eea2e70114689ea39025a60c1349f7564977626c5b0974f378a8)
 * has one additional entry after get_camera_info. It is not called here.
 * Offsets were verified in HMI and its method trampolines, including the
 * identifiable torch implementation. This is a device-specific ABI prefix.
 */
struct camera_module {
    struct hw_module common;
    int (*get_number_of_cameras)(void);
    int (*get_camera_info)(int, struct camera_info *);
    void *vendor_extension;
    void *set_callbacks, *get_vendor_tag_ops, *open_legacy, *set_torch_mode;
    int (*init)(void);
    /* Only the stable prefix through init is accessed. */
};
_Static_assert(sizeof(struct hw_module) == 248, "Android LP64 hw_module ABI");
_Static_assert(offsetof(struct camera_module, get_number_of_cameras) == 248,
               "Android camera method ABI");
_Static_assert(offsetof(struct camera_module, init) == 304,
               "Matching Samsung camera initialization ABI");
_Static_assert(offsetof(struct camera_info, static_camera_characteristics) == 16,
               "Android camera_info ABI");
_Static_assert(sizeof(struct camera3_request)==64 && sizeof(struct camera3_result)==64,
               "Android HAL3 request/result ABI");
_Static_assert(sizeof(struct camera3_stream_buffer)==32 && sizeof(struct camera3_stream)==96,
               "Android HAL3 buffer/stream ABI");

int main(int argc, char **argv, char **envp) {
    (void)envp;
    puts("CAMERA_BIONIC_RUNTIME_READY");
    fflush(0);
    if (argc == 2 && strcmp(argv[1], "--smoke") == 0) return 0;
    if (argc == 2 && strcmp(argv[1], "--buffer-check") == 0) {
        struct buffer_allocator a={0};
        int rc=allocator_open(&a);
        if (rc) return rc;
        buffer_handle buffer=0;
        rc=buffer_allocate(&a,0x20000,&buffer);
        if (!rc) rc=buffer_read(&a,buffer,-1,0);
        if (buffer) { int released=a.release(a.device,buffer); printf("CAMERA_BUFFER_RELEASE result=%d\n",released); if (!rc) rc=released; }
        a.device->common.close(&a.device->common);
        return rc;
    }
    if (argc == 2 && strcmp(argv[1], "--allocator-check") == 0) {
        void *allocator = dlopen("/vendor/lib64/hw/gralloc.bengal.so", 2);
        if (!allocator) { printf("ALLOCATOR_LOAD_ERROR: %s\n", dlerror()); return 20; }
        struct hw_module *module = dlsym(allocator, "HMI");
        if (!module || !module->methods) return 21;
        printf("ALLOCATOR_MODULE name=%s api=0x%04x\n", module->name, module->module_api_version);
        module->dso = allocator;
        struct hw_module_methods *methods = module->methods;
        struct hw_device *device = 0;
        int rc = methods->open(module, "gralloc", &device);
        printf("ALLOCATOR_OPEN result=%d device=%s\n", rc, device ? "present" : "absent");
        fflush(0);
        if (rc || !device || !device->close) return 22;
        printf("ALLOCATOR_DEVICE version=0x%08x\n", device->version);
        rc = device->close(device);
        printf("ALLOCATOR_CLOSE result=%d\n", rc);
        return rc ? 23 : 0;
    }
    int open_check = argc == 2 && strcmp(argv[1], "--open-check") == 0;
    int capabilities=argc==2 && strcmp(argv[1],"--stream-capabilities")==0;
    int stream_check = argc == 2 && strcmp(argv[1], "--stream-check") == 0;
    int preview=argc==2 && (strcmp(argv[1],"--preview-rear")==0 || strcmp(argv[1],"--preview-front")==0);
    int photo=argc==2 && (strcmp(argv[1],"--photo-rear")==0 || strcmp(argv[1],"--photo-front")==0);
    int full_capture=photo || (argc==2 && (strcmp(argv[1],"--full-capture-check")==0 || strcmp(argv[1],"--front-full-capture-check")==0));
    int color_check=argc==2 && (strcmp(argv[1],"--color-capture-check")==0 || strcmp(argv[1],"--front-color-capture-check")==0);
    int capture_check = preview || full_capture || color_check || (argc==2 && (strcmp(argv[1],"--capture-check")==0 || strcmp(argv[1],"--front-capture-check")==0));
    int target=argc==2 && (strcmp(argv[1],"--front-capture-check")==0 || strcmp(argv[1],"--preview-front")==0 || strcmp(argv[1],"--front-full-capture-check")==0 || strcmp(argv[1],"--front-color-capture-check")==0 || strcmp(argv[1],"--photo-front")==0) ? 1 : 0;
    if (preview || full_capture) { signal(15,request_stop); signal(2,request_stop); }
    if (color_check) swap_chroma=0;
    stream_check=stream_check || capture_check;
    open_check = open_check || stream_check;
    if (argc != 2 || (strcmp(argv[1], "--enumerate") != 0 && !open_check && !capabilities)) {
        puts("Usage: camera-hal-enumerate --smoke|--enumerate|--open-check|--stream-check");
        return 2;
    }
    void *handle = dlopen("/vendor/lib64/hw/camera.qcom.so", 2);
    if (!handle) { printf("CAMERA_HAL_LOAD_ERROR: %s\n", dlerror()); return 3; }
    struct camera_module *module = dlsym(handle, "HMI");
    if (!module || !module->common.id || strcmp(module->common.id, "camera") ||
        module->common.module_api_version != 0x205 ||
        !module->get_number_of_cameras || !module->get_camera_info) {
        puts("CAMERA_HAL_INVALID_MODULE"); return 4;
    }
    module->common.dso = handle;
    printf("Camera module: %s api=0x%04x\n", module->common.name,
           module->common.module_api_version);
    fflush(0);
    if (module->common.module_api_version >= 0x204 && module->init) {
        int rc = module->init();
        printf("Camera module init result=%d\n", rc);
        fflush(0);
        if (rc) return 5;
    }
    int count = module->get_number_of_cameras();
    printf("CAMERA_HAL_CAMERA_COUNT=%d\n", count);
    fflush(0);
    if (count < 0 || count > 16) return 6;
    for (int i = 0; i < count; ++i) {
        if (capture_check && i!=target) continue;
        struct camera_info info = {0};
        int rc = module->get_camera_info(i, &info);
        printf("Camera id=%d info_result=%d facing=%d orientation=%d api=0x%04x metadata=%s\n",
               i, rc, info.facing, info.orientation, info.device_version,
               info.static_camera_characteristics ? "present" : "absent");
        if (rc) return 7;
        if (capabilities) { rc=stream_capabilities(i,info.static_camera_characteristics); if (rc) return rc; }
        if (full_capture) {
            rc=full_capture_size(info.static_camera_characteristics,&buffer_width,&buffer_height);
            if (rc) return rc;
            printf("CAMERA_FULL_CAPTURE_SIZE id=%d width=%u height=%u\n",i,buffer_width,buffer_height);
        }
        if (open_check) {
            char id[2] = {(char)('0'+i), 0};
            struct hw_device *device = 0;
            struct hw_module_methods *methods = module->common.methods;
            if (i > 9 || !methods || !methods->open) return 9;
            rc = methods->open(&module->common, id, &device);
            printf("CAMERA_OPEN id=%d result=%d device=%s\n", i, rc,
                   device ? "present" : "absent");
            fflush(0);
            if (rc || !device || !device->close) return 10;
            struct camera3_device *camera = (struct camera3_device *)device;
            printf("CAMERA_DEVICE id=%d tag=0x%08x version=0x%08x\n",
                   i, device->tag, device->version);
            if (device->tag != 0x48574454 || !camera->ops || !camera->ops->initialize)
                return 12;
            int initialized = camera->ops->initialize(camera, &callbacks);
            printf("CAMERA_INITIALIZE id=%d result=%d\n", i, initialized);
            fflush(0);
            if (initialized) { device->close(device); return 13; }
            int configured = 0;
            struct camera3_stream stream = {.width=buffer_width, .height=buffer_height, .format=0x23};
            struct camera3_stream *streams[] = {&stream};
            struct camera3_configuration configuration = {.num_streams=1, .streams=streams};
            if (stream_check) {
                configured = camera->ops->configure(camera, &configuration);
                printf("CAMERA_CONFIGURE id=%d result=%d usage=0x%x max_buffers=%u\n",
                       i, configured, stream.usage, stream.max_buffers);
                fflush(0);
            }
            struct buffer_allocator allocator={0};
            buffer_handle buffer=0;
            int captured=0;
            if (capture_check && !configured) {
                captured=allocator_open(&allocator);
                if (!captured) captured=buffer_allocate(&allocator,stream.usage,&buffer);
                if (!captured && camera->ops->default_settings && camera->ops->capture && camera->ops->flush) {
                    const void *settings=camera->ops->default_settings(camera,full_capture?2:1);
                    struct camera3_stream_buffer output={.stream=&stream,.buffer=&buffer,.acquire_fence=-1,.release_fence=-1};
                    expected_buffer=buffer;
                    buffer_fence=-1;
                    captured=settings ? 0 : 28;
                    uint32_t completed=0;
                    for (uint32_t frame=1;frame && (preview || frame<=(full_capture?15U:30U)) && !captured && !stop_requested;++frame) {
                        /* HAL takes ownership of the previous release fence as
                         * the next acquire fence. The handle stays allocated
                         * until flush/close; only one request is in flight. */
                        output.acquire_fence=buffer_fence;
                        buffer_fence=-1; buffer_status=-1;
                        expected_frame=frame;
                        __atomic_store_n(&buffer_returned,0,__ATOMIC_RELEASE);
                        struct camera3_request request={.frame_number=frame,.settings=frame==1?settings:0,
                            .num_output_buffers=1,.output_buffers=&output};
                        captured=camera->ops->capture(camera,&request);
                        printf("CAMERA_REQUEST id=%d frame=%u result=%d\n",i,frame,captured);
                        fflush(0);
                        if (captured && output.acquire_fence>=0) close(output.acquire_fence);
                        if (!captured) {
                            for (int wait=0;wait<1200 && !__atomic_load_n(&buffer_returned,__ATOMIC_ACQUIRE);++wait) usleep(10000);
                            captured=__atomic_load_n(&buffer_returned,__ATOMIC_ACQUIRE) ? buffer_status : 29;
                            printf("CAMERA_CAPTURE id=%d frame=%u result=%d buffer_returned=%d\n",i,frame,captured,buffer_returned);
                        }
                        if (!captured) ++completed;
                        if (!captured && preview) {
                            captured=buffer_read(&allocator,buffer,buffer_fence,"/run/gta4l-camera/frame.ppm");
                            buffer_fence=-1;
                        }
                    }
                    printf("CAMERA_SEQUENCE id=%d completed=%u preview=%d stop_requested=%d\n",i,completed,preview,stop_requested);
                    int flushed=camera->ops->flush(camera);
                    printf("CAMERA_FLUSH id=%d result=%d\n",i,flushed);
                    if (!captured && flushed) captured=flushed;
                    if (!preview && stop_requested && !captured) captured=35;
                    if (!captured && !preview) captured=buffer_read(&allocator,buffer,buffer_fence,
                        photo ? "/run/gta4l-camera/photo.ppm" :
                        i ? "/data/vendor/camera/front.ppm" : "/data/vendor/camera/rear.ppm");
                    else if (buffer_returned && buffer_fence>=0) close(buffer_fence);
                    if (!captured && color_check) {
                        swap_chroma=1;
                        captured=buffer_read(&allocator,buffer,-1,
                            i ? "/data/vendor/camera/front-swapped.ppm" : "/data/vendor/camera/rear-swapped.ppm");
                    }
                } else if (!captured) captured=30;
            }
            int closed = device->close(device);
            printf("CAMERA_CLOSE id=%d result=%d\n", i, closed);
            fflush(0);
            if (closed) return 11;
            if (buffer) { int released=allocator.release(allocator.device,buffer); printf("CAMERA_BUFFER_RELEASE result=%d\n",released); if (!captured) captured=released; }
            if (allocator.device) allocator.device->common.close(&allocator.device->common);
            if (captured) return captured;
            if (configured) return 14;
        }
    }
    puts("CAMERA_HAL_ENUMERATION_END");
    return count ? 0 : 8;
}

/* This executable has no constructors or TLS data. Bionic initializes itself
 * through the matching stock linker; its normal __libc_init calls main/exit.
 */
struct structors_array { void *preinit_array, *init_array, *fini_array; };
extern void __libc_init(void *, void (*)(void),
    int (*)(int, char **, char **), const struct structors_array *)
    __attribute__((noreturn));
__attribute__((used, visibility("hidden")))
void gta4l_start_main(void *raw_args) {
    static const struct structors_array arrays = {0};
    __libc_init(raw_args, 0, main, &arrays);
}
__asm__(".text\n.global _start\n.type _start,%function\n_start:\n"
        "mov x29,#0\nmov x30,#0\nmov x0,sp\nb gta4l_start_main\n"
        ".size _start,.-_start\n");
