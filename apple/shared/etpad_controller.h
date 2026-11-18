/* ETPad controller input. Copyright (C) 2026 ETPad contributors.
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Included by sdl_input.c after its controller state declarations.
 * Every button is one plain key (no hidden layers) so binds stay predictable.
 * Releases reuse the key sent at press.
 */
static int etpadHeldKeys[32];
static int etpadSentAxes[4];

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
	/* Right shoulder belongs to the native quick-chat wheel. */
	if (source == SDL_CONTROLLER_BUTTON_RIGHTSHOULDER)
	{
		return 0;
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
	for (i = 0; i < 4; ++i)
	{
		etpadSentAxes[i] = 0;
	}
}
/* Analog sticks, independent of key binds. A radial dead zone keeps diagonals
 * smooth. Movement is linear; look uses a curve for fine aim near center and
 * full speed at the rim. j_yaw/j_pitch set speed (and sign, for invert). */
static void ETPad_SendAxis(int slot, int axis, int value)
{
	if (etpadSentAxes[slot] != value)
	{
		etpadSentAxes[slot] = value;
		Com_QueueEvent(lasttime, SE_JOYSTICK_AXIS, axis, value, 0, NULL);
	}
}

static void ETPad_Stick(int xAxis, int yAxis, float deadZone, float exponent, float out[2])
{
	float x = SDL_GameControllerGetAxis(gamepad, xAxis) / 32767.0f;
	float y = SDL_GameControllerGetAxis(gamepad, yAxis) / 32767.0f;
	float length = sqrtf(x * x + y * y);
	out[0] = out[1] = 0;
	if (length > deadZone)
	{
		float scaled = (length > 1.0f ? 1.0f : length);
		scaled = powf((scaled - deadZone) / (1.0f - deadZone), exponent);
		out[0] = x / length * scaled;
		out[1] = y / length * scaled;
	}
}

static void ETPad_StickAxes(void)
{
	float move[2], look[2];
	float deadZone = in_joystickThreshold->value;
	if (deadZone < 0.08f || deadZone > 0.5f)
	{
		deadZone = 0.18f;
	}
	ETPad_Stick(SDL_CONTROLLER_AXIS_LEFTX, SDL_CONTROLLER_AXIS_LEFTY, deadZone, 1.0f, move);
	ETPad_Stick(SDL_CONTROLLER_AXIS_RIGHTX, SDL_CONTROLLER_AXIS_RIGHTY, deadZone * 0.8f, 1.8f, look);
#ifdef ETPAD_IOS
	if (etpad_suspend_look)
	{
		look[0] = look[1] = 0;
	}
#endif
	ETPad_SendAxis(0, Cvar_VariableIntegerValue("j_side_axis"), (int)(move[0] * 32767));
	ETPad_SendAxis(1, Cvar_VariableIntegerValue("j_forward_axis"), (int)(move[1] * 32767));
	ETPad_SendAxis(2, Cvar_VariableIntegerValue("j_yaw_axis"), (int)(look[0] * 32767));
	ETPad_SendAxis(3, Cvar_VariableIntegerValue("j_pitch_axis"), (int)(look[1] * 32767));
}
