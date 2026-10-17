/* Exercise full-panel, odd-size and floating-point offscreen texture sampling. */
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void fail(const char *s)
{
    fprintf(stderr, "%s EGL=0x%x GL=0x%x\n", s, eglGetError(), glGetError());
    exit(1);
}
static GLuint shader(GLenum type, const char *text)
{
    GLuint s=glCreateShader(type); GLint ok; char log[2048];
    glShaderSource(s,1,&text,NULL); glCompileShader(s); glGetShaderiv(s,GL_COMPILE_STATUS,&ok);
    if (!ok) { glGetShaderInfoLog(s,sizeof(log),NULL,log); fprintf(stderr,"%s\n",log); fail("shader"); }
    return s;
}
static GLuint program(const char *fragment)
{
    const char *vertex="#version 300 es\nlayout(location=0) in vec2 p; out highp vec2 uv;"
        "void main(){uv=(p+1.0)*0.5;gl_Position=vec4(p,0.0,1.0);}";
    GLuint p=glCreateProgram(),v=shader(GL_VERTEX_SHADER,vertex),f=shader(GL_FRAGMENT_SHADER,fragment);
    GLint ok; glAttachShader(p,v); glAttachShader(p,f); glLinkProgram(p); glGetProgramiv(p,GL_LINK_STATUS,&ok);
    if (!ok) fail("link");
    glDeleteShader(v); glDeleteShader(f); return p;
}
static void target(GLuint fbo, GLuint tex, GLenum format, int w, int h)
{
    glBindTexture(GL_TEXTURE_2D,tex); glTexStorage2D(GL_TEXTURE_2D,1,format,w,h);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
    glBindFramebuffer(GL_FRAMEBUFFER,fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,tex,0);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE) fail("framebuffer");
}
int main(void)
{
    PFNEGLGETPLATFORMDISPLAYEXTPROC get=(PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    if (!get) fail("platform display");
    EGLDisplay display=get(EGL_PLATFORM_SURFACELESS_MESA,EGL_DEFAULT_DISPLAY,NULL);
    EGLint major,minor,count; EGLConfig config;
    const EGLint attrs[]={EGL_SURFACE_TYPE,EGL_PBUFFER_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_ES3_BIT,
        EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8,EGL_NONE};
    const EGLint ctxattrs[]={EGL_CONTEXT_CLIENT_VERSION,3,EGL_NONE};
    const EGLint surfaceattrs[]={EGL_WIDTH,16,EGL_HEIGHT,16,EGL_NONE};
    if (!eglInitialize(display,&major,&minor)||!eglBindAPI(EGL_OPENGL_ES_API)||
        !eglChooseConfig(display,attrs,&config,1,&count)||count!=1) fail("EGL config");
    EGLContext ctx=eglCreateContext(display,config,EGL_NO_CONTEXT,ctxattrs);
    EGLSurface surface=eglCreatePbufferSurface(display,config,surfaceattrs);
    if (!eglMakeCurrent(display,surface,surface,ctx)) fail("make current");
    const char *renderer=(const char *)glGetString(GL_RENDERER);
    printf("TEXTURE_TEST_RENDERER %s\n",renderer);
    if (!renderer||(!strstr(renderer,"Adreno")&&!strstr(renderer,"llvmpipe"))) fail("unexpected renderer");
    const char *paint="#version 300 es\nprecision highp float; in highp vec2 uv; out vec4 color;"
        "void main(){color=vec4(uv,0.25,1.0);}";
    const char *sample="#version 300 es\nprecision highp float; in highp vec2 uv; out vec4 color;"
        "uniform sampler2D image;uniform int turn;void main(){vec2 q=uv;"
        "if(turn==1)q=vec2(uv.y,1.0-uv.x);if(turn==2)q=1.0-uv;"
        "if(turn==3)q=vec2(1.0-uv.y,uv.x);color=texture(image,q);}";
    GLuint p=program(paint),s=program(sample),vbo,vao;
    const float vertices[]={-1,-1,3,-1,-1,3};
    glGenVertexArrays(1,&vao); glBindVertexArray(vao);
    glGenBuffers(1,&vbo); glBindBuffer(GL_ARRAY_BUFFER,vbo);
    glBufferData(GL_ARRAY_BUFFER,sizeof(vertices),vertices,GL_STATIC_DRAW);
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,0,NULL); glEnableVertexAttribArray(0);
    const int sizes[][2]={{512,512},{1200,2000},{2000,1200},{1200,2001},{2001,1200},{1201,2001}};
    const GLenum formats[]={GL_RGBA8,GL_RGBA16F}; unsigned long long checked=0,errors=0;
    for (unsigned fmt=0;fmt<2;fmt++) for (unsigned dim=0;dim<6;dim++) {
        int w=sizes[dim][0],h=sizes[dim][1]; GLuint tex[2],fbo[2];
        glGenTextures(2,tex); glGenFramebuffers(2,fbo);
        target(fbo[0],tex[0],formats[fmt],w,h); target(fbo[1],tex[1],GL_RGBA8,w,h);
        glBindFramebuffer(GL_FRAMEBUFFER,fbo[0]); glViewport(0,0,w,h);
        glUseProgram(p); glDrawArrays(GL_TRIANGLES,0,3);
        glBindFramebuffer(GL_FRAMEBUFFER,fbo[1]); glUseProgram(s);
        glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D,tex[0]);
        glUniform1i(glGetUniformLocation(s,"image"),0);
        unsigned char *pixels=malloc((size_t)w*h*4); if (!pixels) fail("allocation");
        unsigned long long wrong=0;
        for (int turn=0;turn<4;turn++) {
            glUniform1i(glGetUniformLocation(s,"turn"),turn); glDrawArrays(GL_TRIANGLES,0,3);
            glReadPixels(0,0,w,h,GL_RGBA,GL_UNSIGNED_BYTE,pixels);
            if (glGetError()!=GL_NO_ERROR) fail("draw or readback");
            for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
                float u=(x+0.5f)/w,v=(y+0.5f)/h,a=u,b=v;
                if(turn==1){a=v;b=1-u;} if(turn==2){a=1-u;b=1-v;} if(turn==3){a=1-v;b=u;}
                unsigned char *q=pixels+((size_t)y*w+x)*4;
                if(abs((int)q[0]-(int)lroundf(a*255))>3||abs((int)q[1]-(int)lroundf(b*255))>3||
                   abs((int)q[2]-64)>3||q[3]<252) {
                    if(wrong<3) printf("BAD_PIXEL turn=%d xy=%d,%d rgba=%u,%u,%u,%u expected=%d,%d,64,255\n",
                        turn,x,y,q[0],q[1],q[2],q[3],(int)lroundf(a*255),(int)lroundf(b*255));
                    wrong++;
                }
                checked++;
            }
        }
        errors+=wrong; printf("TEXTURE_CASE format=%s size=%dx%d turns=4 wrong=%llu\n",fmt?"RGBA16F":"RGBA8",w,h,wrong);
        fflush(stdout); free(pixels); glDeleteFramebuffers(2,fbo); glDeleteTextures(2,tex);
    }
    printf("TEXTURE_PIXEL_CHECKS %llu errors=%llu\n",checked,errors);
    glDeleteProgram(p); glDeleteProgram(s); glDeleteBuffers(1,&vbo); glDeleteVertexArrays(1,&vao);
    eglMakeCurrent(display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
    eglDestroySurface(display,surface); eglDestroyContext(display,ctx); eglTerminate(display);
    return errors?1:0;
}
