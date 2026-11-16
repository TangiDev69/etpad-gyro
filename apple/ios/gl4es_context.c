// Minimal GL4ES lifecycle adapted from TribesPad port/apple/gl4es_context.c.
// Source commit: 3f033e4c4b6a620e8a3cd905565b087adbd2bd0a. GPL-3.0-or-later.
#include <stdlib.h>
#include <EGL/egl.h>
#include <gl4esinit.h>
static void *state;
static int initialized;
void *NewGLState(void *, int);
void ActivateGLState(void *);
void DeleteGLState(void *);
static void *native_proc(const char *name) { return (void *)eglGetProcAddress(name); }
static void framebuffer_size(int *w,int *h)
{
    EGLDisplay d=eglGetCurrentDisplay(); EGLSurface s=eglGetCurrentSurface(EGL_DRAW);
    EGLint width=0,height=0;
    eglQuerySurface(d,s,EGL_WIDTH,&width);eglQuerySurface(d,s,EGL_HEIGHT,&height);
    *w=width;*h=height;
}
void ETPad_GL4ESInitialize(void)
{
    if(!initialized){
        setenv("LIBGL_FBOFORCETEX","0",1);setenv("LIBGL_FB","0",1);
        set_getprocaddress(native_proc);set_getmainfbsize(framebuffer_size);
        initialize_gl4es();initialized=1;
    }
    if(!state)state=NewGLState(NULL,0);
    ActivateGLState(state);
}
void ETPad_GL4ESShutdown(void)
{
    if(state){DeleteGLState(state);state=NULL;}
}
