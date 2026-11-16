// SDL2 adaptation of TribesPad port/apple/angle_sdl.{c,h}; provenance in DECISIONS.md.
#pragma once
#include <SDL2/SDL.h>
SDL_Window *ETPad_CreateWindow(const char *, int, int, int, int, Uint32);
SDL_GLContext ETPad_CreateContext(SDL_Window *);
void ETPad_DeleteContext(SDL_GLContext);
int ETPad_MakeCurrent(SDL_Window *, SDL_GLContext);
void ETPad_SwapWindow(SDL_Window *);
int ETPad_SetSwapInterval(int);
void *ETPad_GetProcAddress(const char *);
#ifndef ETPAD_ANGLE_IMPLEMENTATION
#define SDL_CreateWindow ETPad_CreateWindow
#define SDL_GL_CreateContext ETPad_CreateContext
#define SDL_GL_DeleteContext ETPad_DeleteContext
#define SDL_GL_MakeCurrent ETPad_MakeCurrent
#define SDL_GL_SwapWindow ETPad_SwapWindow
#define SDL_GL_SetSwapInterval ETPad_SetSwapInterval
#define SDL_GL_GetProcAddress ETPad_GetProcAddress
#endif
