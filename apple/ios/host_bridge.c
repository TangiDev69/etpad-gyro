// Native host callbacks run on the engine/UIKit main thread. GPL-3.0-or-later.
#include "../../src/qcommon/q_shared.h"
#include "../../src/qcommon/qcommon.h"
#include "../../src/client/client.h"
#include "../../src/sys/sys_local.h"
#define EXPORT __attribute__((visibility("default")))
EXPORT void etpad_command(const char *text) { Cbuf_AddText(text); Cbuf_AddText("\n"); }
EXPORT void etpad_key(int key,int down) { Com_QueueEvent(0,SE_KEY,key,down,0,NULL); }
EXPORT void etpad_mouse(int dx,int dy) { Com_QueueEvent(0,SE_MOUSE,dx,dy,0,NULL); }
EXPORT void etpad_release_inputs(void) { Key_ClearStates(); }

EXPORT void etpad_frame(void) { Com_Frame(); }
