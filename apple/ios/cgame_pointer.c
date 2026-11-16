// Absolute native pointer for the bundled Legacy limbo/menu interface. GPL-3.0-or-later.
#include "../../src/cgame/cg_local.h"
extern void CG_MouseEvent(int,int);
extern qboolean bg_loadscreeninited;
void ETPad_CGameBeginInit(void)
{
    // dyld may retain framework globals across dlclose. A renderer restart
    // clears font data before the next cgame init, so suppress loading-screen
    // drawing until CG_LoadHudMenu installs the new display context.
    Init_Display(NULL);
    bg_loadscreeninited = qfalse;
}
__attribute__((visibility("default"))) void etpad_module_pointer(float x,float y)
{
    CG_MouseEvent((int)(x*Ccg_WideX(SCREEN_WIDTH)-cgs.cursorX),(int)(y*SCREEN_HEIGHT-cgs.cursorY));
}
