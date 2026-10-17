/* Small bounded native Wayland GLES presentation check. */
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <wayland-client.h>
#include <wayland-egl.h>
#include "xdg-shell-client-protocol.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static struct wl_compositor *compositor;
static struct xdg_wm_base *shell;
static struct wl_egl_window *window;
static int configured, closed, width=640, height=480;

static void ping(void *data, struct xdg_wm_base *base, uint32_t serial)
{ (void)data; xdg_wm_base_pong(base, serial); }
static const struct xdg_wm_base_listener shell_listener = { .ping=ping };
static void registry_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version)
{
    (void)data; (void)version;
    if (!strcmp(interface, "wl_compositor"))
        compositor=wl_registry_bind(registry, name, &wl_compositor_interface, 1);
    if (!strcmp(interface, "xdg_wm_base")) {
        shell=wl_registry_bind(registry, name, &xdg_wm_base_interface, 1);
        xdg_wm_base_add_listener(shell, &shell_listener, NULL);
    }
}
static void registry_remove(void *data, struct wl_registry *registry, uint32_t name)
{ (void)data; (void)registry; (void)name; }
static const struct wl_registry_listener registry_listener={registry_global,registry_remove};
static void surface_configure(void *data, struct xdg_surface *surface, uint32_t serial)
{ (void)data; xdg_surface_ack_configure(surface,serial); configured=1; }
static const struct xdg_surface_listener surface_listener={.configure=surface_configure};
static void top_configure(void *data, struct xdg_toplevel *top, int32_t w, int32_t h, struct wl_array *states)
{
    (void)data; (void)top; (void)states;
    if (w>0 && h>0) {width=w; height=h; if(window) wl_egl_window_resize(window,width,height,0,0);}
}
static void top_close(void *data, struct xdg_toplevel *top)
{ (void)data; (void)top; closed=1; }
static const struct xdg_toplevel_listener top_listener={.configure=top_configure,.close=top_close};
static void check(int ok, const char *message)
{ if(!ok){fprintf(stderr,"%s (EGL 0x%x GL 0x%x)\n",message,eglGetError(),glGetError());exit(1);} }
static GLuint shader(GLenum type,const char *source)
{
    GLuint id=glCreateShader(type); GLint ok; char log[2048];
    glShaderSource(id,1,&source,NULL); glCompileShader(id); glGetShaderiv(id,GL_COMPILE_STATUS,&ok);
    if(!ok){glGetShaderInfoLog(id,sizeof(log),NULL,log);fprintf(stderr,"%s\n",log);}
    check(ok,"Shader compilation failed");return id;
}
int main(int argc,char **argv)
{
    setbuf(stdout,NULL);setbuf(stderr,NULL);puts("WAYLAND_TEST_START");
    int seconds=argc>1?atoi(argv[1]):30;
    check(seconds>=1 && seconds<=60,"Duration must be 1..60 seconds");
    struct wl_display *wl=wl_display_connect(NULL);check(wl!=NULL,"Wayland connection failed");
    struct wl_registry *registry=wl_display_get_registry(wl);
    wl_registry_add_listener(registry,&registry_listener,NULL);
    check(wl_display_roundtrip(wl)>=0 && compositor && shell,"Missing Wayland globals");
    puts("Wayland globals ready");
    struct wl_surface *surface=wl_compositor_create_surface(compositor);
    struct xdg_surface *xdg=xdg_wm_base_get_xdg_surface(shell,surface);
    xdg_surface_add_listener(xdg,&surface_listener,NULL);
    struct xdg_toplevel *top=xdg_surface_get_toplevel(xdg);
    xdg_toplevel_add_listener(top,&top_listener,NULL);
    xdg_toplevel_set_title(top,"Adreno OpenGL test - rotating green triangle");
    xdg_toplevel_set_app_id(top,"gta4l-gpu-test");
    wl_surface_commit(surface);
    while(!configured) check(wl_display_dispatch(wl)>=0,"Initial configure failed");
    puts("Window configured");
    window=wl_egl_window_create(surface,width,height);check(window!=NULL,"Native window creation failed");
    PFNEGLGETPLATFORMDISPLAYEXTPROC get_display=(PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    check(get_display!=NULL,"Missing EGL platform entry point");
    EGLDisplay display=get_display(EGL_PLATFORM_WAYLAND_EXT,wl,NULL);EGLint major,minor,count;EGLConfig config;
    const EGLint attr[]={EGL_SURFACE_TYPE,EGL_WINDOW_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_ES2_BIT,EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_NONE};
    const EGLint ctx_attr[]={EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};
    check(display!=EGL_NO_DISPLAY && eglInitialize(display,&major,&minor),"Wayland EGL initialization failed");
    puts("EGL initialized");
    check(eglBindAPI(EGL_OPENGL_ES_API) && eglChooseConfig(display,attr,&config,1,&count) && count==1,"Missing Wayland EGL configuration");
    EGLContext context=eglCreateContext(display,config,EGL_NO_CONTEXT,ctx_attr);
    puts("EGL context created");
    PFNEGLCREATEPLATFORMWINDOWSURFACEEXTPROC create_surface=(PFNEGLCREATEPLATFORMWINDOWSURFACEEXTPROC)eglGetProcAddress("eglCreatePlatformWindowSurfaceEXT");
    check(create_surface!=NULL,"Missing EGL platform-surface entry point");
    EGLSurface egl_surface=create_surface(display,config,window,NULL);
    puts("EGL surface created");
    check(context!=EGL_NO_CONTEXT && egl_surface!=EGL_NO_SURFACE && eglMakeCurrent(display,egl_surface,egl_surface,context),"Wayland EGL context failed");
    puts("EGL context current");
    const char *renderer=(const char*)glGetString(GL_RENDERER);
    printf("GL renderer: %s\nGL version: %s\n",renderer,glGetString(GL_VERSION));fflush(stdout);
    check(renderer && strstr(renderer,"Adreno") && !strstr(renderer,"llvmpipe"),"Required Adreno renderer was not selected");
    GLuint vs=shader(GL_VERTEX_SHADER,"attribute vec2 position;uniform float angle;void main(){float c=cos(angle),s=sin(angle);gl_Position=vec4(c*position.x-s*position.y,s*position.x+c*position.y,0.,1.);}");
    GLuint fs=shader(GL_FRAGMENT_SHADER,"precision mediump float;void main(){gl_FragColor=vec4(0.,1.,0.,1.);}");
    GLuint program=glCreateProgram();glAttachShader(program,vs);glAttachShader(program,fs);glBindAttribLocation(program,0,"position");glLinkProgram(program);
    GLint linked;glGetProgramiv(program,GL_LINK_STATUS,&linked);check(linked,"Linking failed");
    const GLfloat vertices[]={-.6f,-.5f,.6f,-.5f,0.f,.6f};GLuint buffer;glGenBuffers(1,&buffer);glBindBuffer(GL_ARRAY_BUFFER,buffer);glBufferData(GL_ARRAY_BUFFER,sizeof(vertices),vertices,GL_STATIC_DRAW);
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,0,NULL);glEnableVertexAttribArray(0);glUseProgram(program);
    GLint angle=glGetUniformLocation(program,"angle");check(angle>=0,"Missing rotation uniform");
    eglSwapInterval(display,1);struct timespec start,now;clock_gettime(CLOCK_MONOTONIC,&start);unsigned frames=0;
    for(;;){
        clock_gettime(CLOCK_MONOTONIC,&now);double elapsed=now.tv_sec-start.tv_sec+(now.tv_nsec-start.tv_nsec)/1e9;
        if(closed || elapsed>=seconds) break;
        check(wl_display_roundtrip(wl)>=0,"Wayland event dispatch failed");
        glViewport(0,0,width,height);glClearColor(.2f,0.f,.35f,1.f);glClear(GL_COLOR_BUFFER_BIT);glUniform1f(angle,(GLfloat)elapsed);glDrawArrays(GL_TRIANGLES,0,3);
        if(!frames){GLubyte pixel[4];glReadPixels(width/2,height/2,1,1,GL_RGBA,GL_UNSIGNED_BYTE,pixel);check(pixel[0]<5 && pixel[1]>250 && pixel[2]<5,"Native surface pixel readback failed");}
        check(glGetError()==GL_NO_ERROR,"GL rendering error");check(eglSwapBuffers(display,egl_surface),"Native Wayland presentation failed");frames++;
        const struct timespec pause={0,16000000};nanosleep(&pause,NULL);
    }
    printf("Presented %u native Wayland frames\nGPU_WAYLAND_PRESENT_PASS\n",frames);
    glDeleteBuffers(1,&buffer);glDeleteProgram(program);glDeleteShader(vs);glDeleteShader(fs);
    eglMakeCurrent(display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);eglDestroySurface(display,egl_surface);eglDestroyContext(display,context);eglTerminate(display);
    wl_egl_window_destroy(window);xdg_toplevel_destroy(top);xdg_surface_destroy(xdg);wl_surface_destroy(surface);xdg_wm_base_destroy(shell);wl_compositor_destroy(compositor);wl_registry_destroy(registry);wl_display_disconnect(wl);
    return 0;
}
