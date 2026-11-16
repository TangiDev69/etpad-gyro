/* ETPad controller layers. Copyright (C) 2026 ETPad contributors.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Included by sdl_input.c after its controller state declarations.
 * Key releases retain the bank selected at press, even if a shoulder changes.
 */
static int etpadHeldKeys[32];

static qboolean ETPad_ControllerEnabled(void)
{
	return Cvar_Get("etpad_controller", "1", CVAR_ARCHIVE)->integer != 0;
}

static int ETPad_ControllerKey(int source, int baseKey, qboolean pressed)
{
	int key = baseKey;
	if (source >= 32)
	{
		return baseKey;
	}
	if (!pressed)
	{
		key = etpadHeldKeys[source];
		etpadHeldKeys[source] = 0;
		return key;
	}
	if (!ETPad_ControllerEnabled())
	{
		etpadHeldKeys[source] = baseKey;
		return baseKey;
	}
	if (source == SDL_CONTROLLER_BUTTON_LEFTSHOULDER || source == SDL_CONTROLLER_BUTTON_RIGHTSHOULDER)
	{
		return 0;
	}
	/* Left shoulder: utilities/chat. Right shoulder: weapon slots. */
	if (source < 15 && SDL_GameControllerGetButton(gamepad, SDL_CONTROLLER_BUTTON_LEFTSHOULDER))
	{
		key = K_AUX1 + source;
	}
	else if (source < 15 && SDL_GameControllerGetButton(gamepad, SDL_CONTROLLER_BUTTON_RIGHTSHOULDER))
	{
		key = K_JOY1 + source;
	}
	etpadHeldKeys[source] = key;
	return key;
}

static void ETPad_ReleaseController(void)
{
	int i;
	for (i = 0; i < 32; ++i)
	{
		if (etpadHeldKeys[i])
		{
			Com_QueueEvent(lasttime, SE_KEY, etpadHeldKeys[i], qfalse, 0, NULL);
			etpadHeldKeys[i] = 0;
		}
	}
	for (i = 0; i < MAX_JOYSTICK_AXIS; ++i)
	{
		Com_QueueEvent(lasttime, SE_JOYSTICK_AXIS, i, 0, 0, NULL);
	}
}
