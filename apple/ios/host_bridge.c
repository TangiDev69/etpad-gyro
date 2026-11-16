// Native host callbacks run on the engine/UIKit main thread. GPL-3.0-or-later.
#include "../../src/qcommon/q_shared.h"
#include "../../src/qcommon/qcommon.h"
#include "../../src/client/client.h"
#include "../../src/sys/sys_local.h"
#define EXPORT __attribute__((visibility("default")))
EXPORT void etpad_command(const char *text) { Cbuf_AddText(text); Cbuf_AddText("\n"); }
EXPORT void etpad_key(int key,int down) { Com_QueueEvent(0,SE_KEY,key,down,0,NULL); }
EXPORT void etpad_mouse(int dx,int dy) { Com_QueueEvent(0,SE_MOUSE,dx,dy,0,NULL); }
EXPORT void etpad_release_inputs(void) {
    Key_ClearStates();
    Cbuf_AddText("-attack;-moveup;-movedown;-prone;-reload;-activate;-scores;-forward;-back;-moveleft;-moveright;-sprint;-leanleft;-leanright\n");
    for(int axis=0;axis<MAX_JOYSTICK_AXIS;axis++)Com_QueueEvent(0,SE_JOYSTICK_AXIS,axis,0,0,NULL);
}

EXPORT void etpad_frame(void) { Com_Frame(); }
EXPORT int etpad_gameplay(void) { return cls.state == CA_ACTIVE && !(Key_GetCatcher() & (KEYCATCH_UI|KEYCATCH_CGAME|KEYCATCH_CONSOLE)); }
EXPORT void etpad_touch_move(float side,float forward)
{
    Com_QueueEvent(0,SE_JOYSTICK_AXIS,Cvar_VariableIntegerValue("j_side_axis"),(int)(side*32767),0,NULL);
    Com_QueueEvent(0,SE_JOYSTICK_AXIS,Cvar_VariableIntegerValue("j_forward_axis"),(int)(-forward*32767),0,NULL);
}
EXPORT void etpad_pointer(float x,float y,int edge)
{
    // UIKit callbacks may arrive in SDL's nested runloop. Deliver under the
    // engine event/error boundary, in order before the corresponding key edge.
    Com_QueueEvent(0,SE_ETPAD_POINTER,(int)(x*1000000),(int)(y*1000000),0,NULL);
    if(edge>=0)Com_QueueEvent(0,SE_KEY,K_MOUSE1,edge,0,NULL);
}
#include <SDL2/SDL.h>
EXPORT void etpad_hardware_key(int usage,int down)
{
    if(usage<=0 || usage>=SDL_NUM_SCANCODES)return;
    SDL_Event event;SDL_zero(event);
    event.type=down?SDL_KEYDOWN:SDL_KEYUP;event.key.state=down?SDL_PRESSED:SDL_RELEASED;
    event.key.keysym.scancode=(SDL_Scancode)usage;event.key.keysym.sym=SDL_GetKeyFromScancode((SDL_Scancode)usage);
    SDL_PushEvent(&event);
}

EXPORT void etpad_character(int codepoint) { Com_QueueEvent(0,SE_CHAR,codepoint,0,0,NULL); }
