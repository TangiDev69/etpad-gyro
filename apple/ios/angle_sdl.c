// Adapted from TribesPad port/apple/angle_sdl.c at 3f033e4c4b6a620e8a3cd905565b087adbd2bd0a.
// ETPad changes: SDL2 return conventions and a single engine context. GPL-3.0-or-later.
#define ETPAD_ANGLE_IMPLEMENTATION
#define EGL_EGLEXT_PROTOTYPES
#include "angle_sdl.h"
#include <SDL2/SDL_metal.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <EGL/eglext_angle.h>
#include <pthread.h>
#include <stdlib.h>
static EGLDisplay display = EGL_NO_DISPLAY;
static EGLSurface surface = EGL_NO_SURFACE;
static EGLContext context = EGL_NO_CONTEXT;
static SDL_MetalView view;
static SDL_Window *window;
static int failure(const char *operation) { return SDL_SetError("ANGLE %s: EGL 0x%x", operation, eglGetError()); }
SDL_Window *ETPad_CreateWindow(const char *title,int x,int y,int w,int h,Uint32 flags)
{
    return SDL_CreateWindow(title,x,y,w,h,(flags & ~SDL_WINDOW_OPENGL) | SDL_WINDOW_METAL);
}
SDL_GLContext ETPad_CreateContext(SDL_Window *target)
{
    if (!pthread_main_np() || context != EGL_NO_CONTEXT) { SDL_SetError("ETPad requires one main-thread GL context"); return NULL; }
    const EGLint backend[]={EGL_PLATFORM_ANGLE_TYPE_ANGLE,EGL_PLATFORM_ANGLE_TYPE_METAL_ANGLE,EGL_NONE};
    const EGLint attributes[]={EGL_SURFACE_TYPE,EGL_WINDOW_BIT,EGL_RENDERABLE_TYPE,EGL_OPENGL_ES3_BIT,EGL_RED_SIZE,8,EGL_GREEN_SIZE,8,EGL_BLUE_SIZE,8,EGL_ALPHA_SIZE,8,EGL_DEPTH_SIZE,24,EGL_STENCIL_SIZE,8,EGL_NONE};
    const EGLint version[]={EGL_CONTEXT_CLIENT_VERSION,3,EGL_CONTEXT_CLIENT_ARRAYS_ENABLED_ANGLE,EGL_TRUE,EGL_NONE};
    EGLConfig config; EGLint count;
    display=eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,NULL,backend);
    if(display==EGL_NO_DISPLAY || !eglInitialize(display,NULL,NULL))goto fail;
    if(!eglChooseConfig(display,attributes,&config,1,&count) || count!=1)goto fail;
    view=SDL_Metal_CreateView(target); if(!view)goto fail;
    surface=eglCreateWindowSurface(display,config,(EGLNativeWindowType)SDL_Metal_GetLayer(view),NULL);
    if(surface==EGL_NO_SURFACE)goto fail;
    context=eglCreateContext(display,config,EGL_NO_CONTEXT,version);
    if(context==EGL_NO_CONTEXT || !eglMakeCurrent(display,surface,surface,context))goto fail;
    window=target; return (SDL_GLContext)context;
fail:
    failure("create Metal context"); ETPad_DeleteContext((SDL_GLContext)context); return NULL;
}
void ETPad_DeleteContext(SDL_GLContext token)
{
    (void)token;
    if(display!=EGL_NO_DISPLAY){
        eglMakeCurrent(display,EGL_NO_SURFACE,EGL_NO_SURFACE,EGL_NO_CONTEXT);
        if(context!=EGL_NO_CONTEXT)eglDestroyContext(display,context);
        if(surface!=EGL_NO_SURFACE)eglDestroySurface(display,surface);
        eglTerminate(display);
    }
    if(view)SDL_Metal_DestroyView(view);
    context=EGL_NO_CONTEXT;surface=EGL_NO_SURFACE;display=EGL_NO_DISPLAY;view=NULL;window=NULL;
}
int ETPad_MakeCurrent(SDL_Window *target,SDL_GLContext token)
{
    if(target!=window || (EGLContext)token!=context)return SDL_SetError("Invalid ETPad context/window");
    return eglMakeCurrent(display,surface,surface,context)?0:failure("make current");
}
void ETPad_SwapWindow(SDL_Window *target)
{
    if(target==window && !eglSwapBuffers(display,surface))failure("swap buffers");
}
int ETPad_SetSwapInterval(int interval){return eglSwapInterval(display,interval)?0:failure("swap interval");}
void *ETPad_GetProcAddress(const char *name){return (void *)eglGetProcAddress(name);}
