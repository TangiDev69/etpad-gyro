// Private commands shared by the iOS host and its bundled Legacy modules.
// GPL-3.0-or-later; see COPYING.txt.
#ifndef ETPAD_VM_COMMANDS_H
#define ETPAD_VM_COMMANDS_H

// Keep these outside the public ET module command ranges. Coordinates travel
// as integers because VM_Call accepts intptr_t arguments, not floating point.
#define ETPAD_VM_ABSOLUTE_POINTER 0x45545001
#define ETPAD_VM_HUD_FLAGS 0x45545002
// UI module: 1 while one of its text or number fields is being edited.
#define ETPAD_VM_UI_TEXT_EDITING 0x45545003
#define ETPAD_POINTER_SCALE 65536

#define ETPAD_HUD_SCOREBOARD 1
#define ETPAD_HUD_INTERMISSION 2

#endif
