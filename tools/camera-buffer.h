/* Pinned Android 12 gralloc1/native-handle/graphics ABI, used only in the
 * matched stock runtime. All allocations and CPU locks go through gralloc. */
extern int close(int);
extern int usleep(unsigned int);
extern void *fopen(const char *, const char *);
extern size_t fwrite(const void *, size_t, size_t, void *);
extern int fprintf(void *, const char *, ...);
extern int fclose(void *);
extern int rename(const char *,const char *);
struct native_handle { int version, num_fds, num_ints; int data[]; };
typedef const struct native_handle *buffer_handle;
static uint32_t buffer_width=640,buffer_height=480;
/* In this hash-matched CamX/gralloc1 runtime the interleaved color bytes are
 * opposite the returned Cb/Cr labels. Paired captures of the same buffer were
 * compared on the tablet; swapping the chroma samples restores real colors.
 * The adjustment below requires the exact observed interleaved layout. */
static int swap_chroma=1;
struct gralloc1_device {
    struct hw_device common;
    void (*capabilities)(struct gralloc1_device *, uint32_t *, int32_t *);
    void *(*function)(struct gralloc1_device *, int32_t);
};
struct flex_plane {
    uint8_t *top_left;
    int32_t component, bits_per_component, bits_used;
    int32_t h_increment, v_increment, h_subsampling, v_subsampling;
};
struct flex_layout { int32_t format; uint32_t num_planes; struct flex_plane *planes; };
struct gralloc_rect { int32_t left, top, width, height; };
struct buffer_allocator {
    struct gralloc1_device *device;
    int32_t (*create)(struct gralloc1_device *, uint64_t *);
    int32_t (*destroy)(struct gralloc1_device *, uint64_t);
    int32_t (*consumer)(struct gralloc1_device *, uint64_t, uint64_t);
    int32_t (*dimensions)(struct gralloc1_device *, uint64_t, uint32_t, uint32_t);
    int32_t (*format)(struct gralloc1_device *, uint64_t, int32_t);
    int32_t (*producer)(struct gralloc1_device *, uint64_t, uint64_t);
    int32_t (*allocate)(struct gralloc1_device *, uint32_t, const uint64_t *, buffer_handle *);
    int32_t (*release)(struct gralloc1_device *, buffer_handle);
    int32_t (*stride)(struct gralloc1_device *, buffer_handle, uint32_t *);
    int32_t (*plane_count)(struct gralloc1_device *, buffer_handle, uint32_t *);
    int32_t (*lock_flex)(struct gralloc1_device *, buffer_handle, uint64_t, uint64_t,
                         const struct gralloc_rect *, struct flex_layout *, int32_t);
    int32_t (*unlock)(struct gralloc1_device *, buffer_handle, int32_t *);
};
static int allocator_open(struct buffer_allocator *a) {
    void *library = dlopen("/vendor/lib64/hw/gralloc.bengal.so", 2);
    if (!library) { printf("ALLOCATOR_LOAD_ERROR: %s\n", dlerror()); return 20; }
    struct hw_module *module = dlsym(library, "HMI");
    if (!module || !module->methods || module->module_api_version != 0x100) return 21;
    module->dso = library;
    struct hw_device *device = 0;
    int rc = ((struct hw_module_methods *)module->methods)->open(module, "gralloc", &device);
    printf("ALLOCATOR_OPEN result=%d version=0x%08x\n", rc, device ? device->version : 0);
    if (rc || !device || device->version != 0x100) return 22;
    a->device = (struct gralloc1_device *)device;
#define GET(field, index) a->field = a->device->function(a->device, index); if (!a->field) return 24
    GET(create,2); GET(destroy,3); GET(consumer,4); GET(dimensions,5);
    GET(format,6); GET(producer,7); GET(stride,13); GET(allocate,14);
    GET(release,16); GET(plane_count,17); GET(lock_flex,19); GET(unlock,20);
#undef GET
    return 0;
}
static int buffer_allocate(struct buffer_allocator *a, uint64_t producer, buffer_handle *handle) {
    uint64_t descriptor = 0;
    int rc = a->create(a->device, &descriptor);
    if (rc) return rc;
    if (!(rc = a->dimensions(a->device,descriptor,buffer_width,buffer_height)) &&
        !(rc = a->format(a->device,descriptor,0x23)) &&
        !(rc = a->producer(a->device,descriptor,producer)) &&
        !(rc = a->consumer(a->device,descriptor,6)))
        rc = a->allocate(a->device,1,&descriptor,handle);
    int destroyed = a->destroy(a->device,descriptor);
    printf("CAMERA_BUFFER_ALLOCATE result=%d descriptor_destroy=%d\n", rc, destroyed);
    if (rc || !*handle) return rc ? rc : 25;
    uint32_t stride = 0;
    rc = a->stride(a->device,*handle,&stride);
    printf("CAMERA_BUFFER_HANDLE version=%d fds=%d ints=%d stride=%u stride_result=%d\n",
           (*handle)->version,(*handle)->num_fds,(*handle)->num_ints,stride,rc);
    fflush(0);
    return rc;
}
static uint8_t clip_color(int value) { return value < 0 ? 0 : value > 255 ? 255 : (uint8_t)value; }
static int buffer_read(struct buffer_allocator *a, buffer_handle handle, int fence, const char *path) {
    uint32_t count = 0;
    int rc = a->plane_count(a->device,handle,&count);
    if (rc || count != 3) { if (fence >= 0) close(fence); return 26; }
    struct flex_plane planes[3] = {{0}};
    struct flex_layout layout = {.num_planes=count,.planes=planes};
    struct gralloc_rect rect = {.width=(int32_t)buffer_width,.height=(int32_t)buffer_height};
    /* lock_flex owns the acquire fence, including on error, per gralloc1. */
    rc = a->lock_flex(a->device,handle,0,6,&rect,&layout,fence);
    printf("CAMERA_BUFFER_LOCK result=%d format=%d planes=%u\n",rc,layout.format,layout.num_planes);
    if (rc) return rc;
    int valid = layout.format == 7 && layout.num_planes == 3 && layout.planes == planes;
    printf("CAMERA_CHROMA_LAYOUT cb_minus_cr=%lld swap_chroma=%d\n",
           (long long)((intptr_t)planes[1].top_left-(intptr_t)planes[2].top_left),swap_chroma);
    for (int i=0;i<3;++i) {
        printf("CAMERA_BUFFER_PLANE component=%d bits=%d/%d increment=%d,%d subsampling=%d,%d\n",
               planes[i].component,planes[i].bits_used,planes[i].bits_per_component,
               planes[i].h_increment,planes[i].v_increment,planes[i].h_subsampling,planes[i].v_subsampling);
        if (!planes[i].top_left || planes[i].component != (1 << i) ||
            planes[i].bits_used != 8 || planes[i].bits_per_component != 8 ||
            planes[i].h_increment < 1 || planes[i].h_increment > 8 ||
            planes[i].v_increment < ((int32_t)buffer_width/(i?2:1)-1)*planes[i].h_increment+1 ||
            planes[i].v_increment > 65536 ||
            (i && (planes[i].h_subsampling != 2 || planes[i].v_subsampling != 2))) valid=0;
    }
    /* This matching Qualcomm gralloc1 reports the chroma subsampling on the
     * luma plane too. Y remains full resolution: one byte per pixel, with the
     * separately returned row stride. Accept only this observed 1/1 or 2/2
     * luma descriptor; do not apply chroma subsampling when reading luma. */
    if (planes[0].h_increment != 1 ||
        !((planes[0].h_subsampling==1 && planes[0].v_subsampling==1) ||
          (planes[0].h_subsampling==2 && planes[0].v_subsampling==2))) valid=0;
    if (swap_chroma && ((intptr_t)planes[1].top_left-(intptr_t)planes[2].top_left!=1 ||
        planes[1].h_increment!=2 || planes[2].h_increment!=2 ||
        planes[1].v_increment!=planes[2].v_increment)) valid=0;
    int saved = 0;
    if (valid && path) {
        char temporary[256];
        int length=0;
        while (path[length] && length<240) { temporary[length]=path[length]; ++length; }
        temporary[length++]='.'; temporary[length++]='t'; temporary[length++]='m';
        temporary[length++]='p'; temporary[length]=0;
        void *file = fopen(temporary,"wb");
        if (file) {
            saved = fprintf(file,"P6\n%u %u\n255\n",buffer_width,buffer_height) > 0;
            unsigned int minimum=255,maximum=0;
            uint64_t sum=0;
            for (uint32_t y=0;y<buffer_height && saved;++y) {
                uint8_t row[4096*3];
                for (uint32_t x=0;x<buffer_width;++x) {
                    int luma=planes[0].top_left[y*planes[0].v_increment+x*planes[0].h_increment];
                    int cb=planes[1].top_left[(y/2)*planes[1].v_increment+(x/2)*planes[1].h_increment]-128;
                    int cr=planes[2].top_left[(y/2)*planes[2].v_increment+(x/2)*planes[2].h_increment]-128;
                    if (swap_chroma) { int temporary=cb; cb=cr; cr=temporary; }
                    if ((unsigned)luma<minimum) minimum=luma;
                    if ((unsigned)luma>maximum) maximum=luma;
                    sum+=(unsigned)luma;
                    int c=(luma-16)*298;
                    row[3*x]=clip_color((c+409*cr+128)>>8);
                    row[3*x+1]=clip_color((c-100*cb-208*cr+128)>>8);
                    row[3*x+2]=clip_color((c+516*cb+128)>>8);
                }
                saved=fwrite(row,1,buffer_width*3,file)==buffer_width*3;
            }
            if (fclose(file)) saved=0;
            if (saved && rename(temporary,path)) saved=0;
            printf("CAMERA_IMAGE_SAVED success=%d luma_min=%u luma_max=%u luma_mean=%llu\n",
                   saved,minimum,maximum,(unsigned long long)(sum/(buffer_width*buffer_height)));
        }
    }
    int release_fence=-1;
    rc = a->unlock(a->device,handle,&release_fence);
    if (release_fence >= 0) close(release_fence);
    printf("CAMERA_BUFFER_UNLOCK result=%d\n",rc);
    fflush(0);
    return rc ? rc : (!valid || (path && !saved)) ? 27 : 0;
}
