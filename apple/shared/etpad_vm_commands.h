// Private commands shared by the iOS host and its bundled Legacy modules.
// GPL-3.0-or-later; see COPYING.txt.
#ifndef ETPAD_VM_COMMANDS_H
#define ETPAD_VM_COMMANDS_H

// Keep these outside the public ET module command ranges. Coordinates travel
// as integers because VM_Call accepts intptr_t arguments, not floating point.
#define ETPAD_VM_ABSOLUTE_POINTER 0x45545001
#define ETPAD_POINTER_SCALE 65536

#endif
