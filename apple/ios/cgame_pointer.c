// Absolute native pointer for the bundled Legacy limbo/menu interface. GPL-3.0-or-later.
#include "../../src/cgame/cg_local.h"
extern void CG_MouseEvent(int,int);
__attribute__((visibility("default"))) void etpad_module_pointer(float x,float y)
{
    CG_MouseEvent((int)(x*Ccg_WideX(SCREEN_WIDTH)-cgs.cursorX),(int)(y*SCREEN_HEIGHT-cgs.cursorY));
}
