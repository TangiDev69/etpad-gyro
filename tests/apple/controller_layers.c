/* SPDX-License-Identifier: GPL-3.0-or-later
 * Exercise real SDL virtual-controller edges against ETPad's layer routing.
 */
#include <assert.h>
#include <stdio.h>
#include <SDL.h>
#include "../../src/qcommon/keycodes.h"
typedef int qboolean;
enum { qfalse, qtrue, CVAR_ARCHIVE = 1, SE_KEY = 1, SE_JOYSTICK_AXIS = 2, MAX_JOYSTICK_AXIS = 16 };
typedef struct { int integer; } cvar_t;
static cvar_t enabled = {1};
static SDL_GameController *gamepad;
static int lasttime, released;
static cvar_t *Cvar_Get(const char *name, const char *value, int flags) { return &enabled; }
static void Com_QueueEvent(int t, int type, int key, int down, int n, void *p)
{
    if (type == SE_KEY && !down) ++released;
}
#include "../../apple/shared/etpad_controller.h"
static void shoulder(SDL_Joystick *stick, int button, int down)
{
    assert(SDL_JoystickSetVirtualButton(stick, button, down) == 0);
    SDL_JoystickUpdate();
    SDL_GameControllerUpdate();
}
int main(void)
{
    assert(SDL_Init(SDL_INIT_GAMECONTROLLER) == 0);
    int index = SDL_JoystickAttachVirtual(SDL_JOYSTICK_TYPE_GAMECONTROLLER, SDL_CONTROLLER_AXIS_MAX, SDL_CONTROLLER_BUTTON_MAX, 0);
    assert(index >= 0);
    gamepad = SDL_GameControllerOpen(index);
    assert(gamepad);
    SDL_Joystick *stick = SDL_GameControllerGetJoystick(gamepad);
    assert(ETPad_ControllerKey(SDL_CONTROLLER_BUTTON_A, K_PAD0_A, 1) == K_PAD0_A);
    assert(ETPad_ControllerKey(SDL_CONTROLLER_BUTTON_A, K_PAD0_A, 0) == K_PAD0_A);
    shoulder(stick, SDL_CONTROLLER_BUTTON_LEFTSHOULDER, 1);
    assert(ETPad_ControllerKey(SDL_CONTROLLER_BUTTON_A, K_PAD0_A, 1) == K_AUX1);
    shoulder(stick, SDL_CONTROLLER_BUTTON_LEFTSHOULDER, 0);
    assert(ETPad_ControllerKey(SDL_CONTROLLER_BUTTON_A, K_PAD0_A, 0) == K_AUX1);
    shoulder(stick, SDL_CONTROLLER_BUTTON_RIGHTSHOULDER, 1);
    assert(ETPad_ControllerKey(SDL_CONTROLLER_BUTTON_B, K_PAD0_B, 1) == K_JOY2);
    enabled.integer = 0;
    assert(ETPad_ControllerKey(SDL_CONTROLLER_BUTTON_B, K_PAD0_B, 0) == K_JOY2);
    enabled.integer = 1;
    assert(ETPad_ControllerKey(24, K_PAD0_LEFTTRIGGER, 1) == K_PAD0_LEFTTRIGGER);
    assert(ETPad_ControllerKey(SDL_CONTROLLER_BUTTON_X, K_PAD0_X, 1) == K_JOY3);
    ETPad_ReleaseController();
    assert(released == 2);
    for (int i = 0; i < 32; ++i) assert(etpadHeldKeys[i] == 0);
    SDL_GameControllerClose(gamepad);
    SDL_JoystickDetachVirtual(index);
    SDL_Quit();
    puts("PASS: SDL virtual controller, shoulder release ordering, settings change, triggers and unplug cleanup");
}
