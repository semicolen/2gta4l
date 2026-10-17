/* Exercise GPU rendering, linear GBM buffers and downstream display import. */
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <gbm.h>
#include <xf86drm.h>
#include <drm_fourcc.h>
#include <linux/dma-buf.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

static void check(int ok,const char *message)
{if(!ok){fprintf(stderr,"%s (EGL 0x%x GL 0x%x)\n",message,eglGetError(),glGetError());exit(1);}}
int main(void)
{
    int fd=open("/dev/dri/renderD128",O_RDWR|O_CLOEXEC);
    check(fd>=0,"Display DRM open failed");
    struct gbm_device *device=gbm_create_device(fd);check(device!=NULL,"GBM device creation failed");
    const uint64_t modifier=DRM_FORMAT_MOD_LINEAR;
    struct gbm_surface *native=gbm_surface_create_with_modifiers2(device,512,512,GBM_FORMAT_XRGB8888,&modifier,1,GBM_BO_USE_RENDERING|GBM_BO_USE_SCANOUT);
    check(native!=NULL,"Linear GBM surface creation failed");
    PFNEGLGETPLATFORMDISPLAYEXTPROC get_display=(PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    PFNEGLCREATEPLATFORMWINDOWSURFACEEXTPROC create_surface=(PFNEGLCREATEPLATFORMWINDOWSURFACEEXTPROC)eglGetProcAddress("eglCreatePlatformWindowSurfaceEXT");
    check(get_display && create_surface,"Missing EGL platform entry points");
    EGLDisplay display=get_display(EGL_PLATFORM_GBM_KHR,device,NULL);EGLint major,minor,count;EGLConfig configs[64],config=NULL;
    const EGLint attr[]={EGL_SURFACE_TYPE,EGL_WINDOW_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_ES2_BIT,EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_NONE};
    const EGLint ctx_attr[]={EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};
    check(display!=EGL_NO_DISPLAY && eglInitialize(display,&major,&minor),"GBM EGL initialization failed");
    check(eglBindAPI(EGL_OPENGL_ES_API) && eglChooseConfig(display,attr,configs,64,&count),"GBM EGL configuration query failed");
    for(int i=0;i<count;i++){EGLint visual;eglGetConfigAttrib(display,configs[i],EGL_NATIVE_VISUAL_ID,&visual);if((uint32_t)visual==GBM_FORMAT_XRGB8888){config=configs[i];break;}}
    check(config!=NULL,"No XRGB EGL configuration");
    EGLContext context=eglCreateContext(display,config,EGL_NO_CONTEXT,ctx_attr);
    EGLSurface surface=create_surface(display,config,native,NULL);
    check(context!=EGL_NO_CONTEXT && surface!=EGL_NO_SURFACE && eglMakeCurrent(display,surface,surface,context),"GBM GLES context failed");
    const char *renderer=(const char*)glGetString(GL_RENDERER);
    printf("GL renderer: %s\nGL version: %s\n",renderer,glGetString(GL_VERSION));fflush(stdout);
    check(renderer && strstr(renderer,"Adreno") && !strstr(renderer,"llvmpipe"),"Adreno renderer required");
    glViewport(0,0,512,512);glClearColor(1.f,0.f,0.f,1.f);glClear(GL_COLOR_BUFFER_BIT);
    GLubyte pixel[4];glReadPixels(256,256,1,1,GL_RGBA,GL_UNSIGNED_BYTE,pixel);
    check(pixel[0]>250 && pixel[1]<5 && pixel[2]<5 && glGetError()==GL_NO_ERROR,"GBM rendered pixel readback failed");
    check(eglSwapBuffers(display,surface),"GBM surface swap failed");glFinish();
    struct gbm_bo *bo=gbm_surface_lock_front_buffer(native);check(bo!=NULL,"GBM front buffer lock failed");
    const uint64_t actual_modifier=gbm_bo_get_modifier(bo);const uint32_t stride=gbm_bo_get_stride(bo);
    printf("GBM buffer: 512x512 stride=%u modifier=0x%llx\n",stride,(unsigned long long)actual_modifier);fflush(stdout);
    check(actual_modifier==DRM_FORMAT_MOD_LINEAR,"Unexpected buffer modifier");
    int shared=gbm_bo_get_fd(bo);check(shared>=0,"GPU buffer export failed");
    int consumer=open("/dev/dri/renderD128",O_RDWR|O_CLOEXEC);check(consumer>=0,"Display consumer open failed");
    uint32_t handle=0;check(drmPrimeFDToHandle(consumer,shared,&handle)==0 && handle,"Display PRIME import failed");
    printf("Downstream display imported the GPU dma-buf\n");fflush(stdout);
    struct dma_buf_sync sync={.flags=DMA_BUF_SYNC_START|DMA_BUF_SYNC_READ};
    check(ioctl(shared,DMA_BUF_IOCTL_SYNC,&sync)==0,"GPU buffer read synchronization failed");
    size_t length=(size_t)stride*512;void *map=mmap(NULL,length,PROT_READ,MAP_SHARED,shared,0);
    check(map!=MAP_FAILED,"GPU buffer mapping failed");
    uint32_t center;memcpy(&center,(char*)map+256*stride+256*4,sizeof(center));
    printf("Exported display pixel: 0x%08x\n",center);fflush(stdout);
    check((center&0xffffff)==0xff0000,"Exported display pixel was not red");
    munmap(map,length);sync.flags=DMA_BUF_SYNC_END|DMA_BUF_SYNC_READ;
    check(ioctl(shared,DMA_BUF_IOCTL_SYNC,&sync)==0,"GPU buffer read synchronization end failed");
    struct drm_gem_close close_handle={.handle=handle};ioctl(consumer,DRM_IOCTL_GEM_CLOSE,&close_handle);close(consumer);close(shared);
    gbm_surface_release_buffer(native,bo);eglMakeCurrent(display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
    eglDestroySurface(display,surface);eglDestroyContext(display,context);eglTerminate(display);gbm_surface_destroy(native);gbm_device_destroy(device);close(fd);
    puts("GPU_GBM_DISPLAY_IMPORT_PASS");return 0;
}
