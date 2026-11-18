// Native host callbacks run on the engine/UIKit main thread. GPL-3.0-or-later.
#include "../../src/qcommon/q_shared.h"
#include "../../src/qcommon/qcommon.h"
#include "../../src/client/client.h"
#include "../../src/sys/sys_local.h"
#include "host_bridge.h"
#include "../shared/etpad_vm_commands.h"
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
EXPORT int etpad_hud_flags(void)
{
    if (cls.state != CA_ACTIVE || !cls.cgameStarted || !cgvm) return 0;
    // A private read-only VM command preserves the cgame syscall context.
    return (int)VM_Call(cgvm, ETPAD_VM_HUD_FLAGS);
}
EXPORT const char *etpad_renderer(void) { return Cvar_VariableString("cl_renderer"); }
EXPORT int etpad_render_width(void) { return cls.glconfig.vidWidth; }
EXPORT int etpad_render_height(void) { return cls.glconfig.vidHeight; }
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

// iPad pointer handoff. While UIKit locks the pointer for gameplay, SDL's
// GCMouse deltas and buttons drive look/fire. Unlocked pointers (menus,
// launcher) arrive through the native UIKit pointer path instead, so SDL's
// copies are dropped there to avoid a second click.
int etpad_pointer_locked = 0;
int etpad_mouse_activity = 0;
// Set while the quick-chat wheel uses the right stick to pick a message.
int etpad_suspend_look = 0;
EXPORT void etpad_set_suspend_look(int suspend) { etpad_suspend_look = suspend != 0; }
EXPORT void etpad_set_pointer_locked(int locked) { etpad_pointer_locked = locked != 0; }
EXPORT int etpad_take_mouse_activity(void) { int seen = etpad_mouse_activity; etpad_mouse_activity = 0; return seen; }
// 0 disconnected ... CA_ACTIVE in play; see connstate_t.
EXPORT int etpad_client_state(void) { return cls.state; }
EXPORT int etpad_local_server(void) { return com_sv_running && com_sv_running->integer; }
// 1 while ET expects typed text: a UI text field (profile, chat, password) or the console. The
// host then shows the iPad keyboard when no hardware keyboard is attached.
EXPORT int etpad_text_input_active(void)
{
	int catcher = Key_GetCatcher();
	if (catcher & KEYCATCH_CONSOLE)
	{
		return 1;
	}
	if ((catcher & KEYCATCH_UI) && uivm)
	{
		return (int)VM_Call(uivm, ETPAD_VM_UI_TEXT_EDITING) != 0;
	}
	return 0;
}
// Current text of the field being typed into, shown above the iPad keyboard
// because ET's chat box sits low enough to be covered by it.
EXPORT const char *etpad_text_input_preview(void)
{
	if (Key_GetCatcher() & KEYCATCH_CONSOLE)
	{
		return g_consoleField.buffer;
	}
	return Cvar_VariableString("ui_textfield_temp");
}
