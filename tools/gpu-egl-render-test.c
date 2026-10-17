/* Bounded GLES shader/draw/readback check; built locally for the tablet. */
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static void fail(const char *message)
{
    fprintf(stderr, "%s (EGL=0x%x GL=0x%x)\n", message, eglGetError(), glGetError());
    exit(1);
}

static GLuint shader(GLenum type, const char *source)
{
    GLuint id = glCreateShader(type);
    GLint ok;
    char log[2048];
    glShaderSource(id, 1, &source, NULL);
    glCompileShader(id);
    glGetShaderiv(id, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        glGetShaderInfoLog(id, sizeof(log), NULL, log);
        fprintf(stderr, "Shader: %s\n", log);
        fail("Shader compile failed");
    }
    return id;
}

int main(int argc, char **argv)
{
    const int hardware = argc > 1 && !strcmp(argv[1], "--require-hardware");
    PFNEGLGETPLATFORMDISPLAYEXTPROC get_display =
        (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    if (!get_display) fail("Missing platform-display entry point");
    EGLDisplay display = get_display(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, NULL);
    EGLint major, minor, count;
    EGLConfig config;
    const EGLint attributes[] = {EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8, EGL_NONE};
    const EGLint context_attributes[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
    const EGLint surface_attributes[] = {EGL_WIDTH, 512, EGL_HEIGHT, 512, EGL_NONE};
    if (display == EGL_NO_DISPLAY || !eglInitialize(display, &major, &minor))
        fail("Surfaceless EGL initialization failed");
    if (!eglBindAPI(EGL_OPENGL_ES_API) || !eglChooseConfig(display, attributes, &config, 1, &count) || count != 1)
        fail("No GLES pbuffer configuration");
    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
    EGLSurface surface = eglCreatePbufferSurface(display, config, surface_attributes);
    if (context == EGL_NO_CONTEXT || surface == EGL_NO_SURFACE || !eglMakeCurrent(display, surface, surface, context))
        fail("GLES context creation failed");
    const char *renderer = (const char *)glGetString(GL_RENDERER);
    printf("EGL: %d.%d %s\nGL renderer: %s\nGL version: %s\n", major, minor,
        eglQueryString(display, EGL_VENDOR), renderer, glGetString(GL_VERSION));
    if (hardware && (!renderer || !strstr(renderer, "Adreno") || strstr(renderer, "llvmpipe")))
        fail("Required Adreno hardware renderer was not selected");
    GLuint program = glCreateProgram();
    GLuint vs = shader(GL_VERTEX_SHADER, "attribute vec2 position; void main(){gl_Position=vec4(position,0.,1.);}");
    GLuint fs = shader(GL_FRAGMENT_SHADER, "precision mediump float; void main(){gl_FragColor=vec4(1.,0.,0.,1.);}");
    glAttachShader(program, vs);
    glAttachShader(program, fs);
    glBindAttribLocation(program, 0, "position");
    glLinkProgram(program);
    GLint linked;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (!linked) fail("Program linking failed");
    GLuint texture, framebuffer, vertices;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 512, 512, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) fail("Incomplete render target");
    const GLfloat data[] = {-0.8f,-0.8f, 0.8f,-0.8f, 0.f,0.8f};
    glGenBuffers(1, &vertices);
    glBindBuffer(GL_ARRAY_BUFFER, vertices);
    glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(0);
    glUseProgram(program);
    glViewport(0, 0, 512, 512);
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    for (int frame = 0; frame < 120; frame++) {
        glClearColor(0.f,0.f,1.f,1.f);
        glClear(GL_COLOR_BUFFER_BIT);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glFinish();
        GLubyte center[4], corner[4];
        glReadPixels(256, 256, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, center);
        glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, corner);
        if (center[0] < 250 || center[1] > 5 || center[2] > 5 || center[3] < 250 ||
            corner[0] > 5 || corner[1] > 5 || corner[2] < 250 || corner[3] < 250)
            fail("Rendered pixel readback was incorrect");
        if (glGetError() != GL_NO_ERROR) fail("GL error during render/readback");
    }
    clock_gettime(CLOCK_MONOTONIC, &end);
    const double seconds = end.tv_sec - start.tv_sec + (end.tv_nsec - start.tv_nsec) / 1e9;
    printf("120 shader frames and 240 pixel checks passed in %.3f seconds\n", seconds);
    glDeleteBuffers(1, &vertices);
    glDeleteFramebuffers(1, &framebuffer);
    glDeleteTextures(1, &texture);
    glDeleteProgram(program);
    glDeleteShader(vs);
    glDeleteShader(fs);
    eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroySurface(display, surface);
    eglDestroyContext(display, context);
    eglTerminate(display);
    puts("GPU_EGL_RENDER_READBACK_PASS");
    return 0;
}
