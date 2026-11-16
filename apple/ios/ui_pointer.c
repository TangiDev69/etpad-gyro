// Absolute native touch/trackpad pointer for the bundled Legacy UI. GPL-3.0-or-later.
#include "../../src/ui/ui_local.h"
extern void UI_MouseEvent(int,int);
void etpad_module_pointer(float x,float y)
{
    UI_MouseEvent((int)(x*Cui_WideX(SCREEN_WIDTH)-uiInfo.uiDC.cursorx),(int)(y*SCREEN_HEIGHT-uiInfo.uiDC.cursory));
}
