/* ETPad native/controller menu action. GPL-3.0-or-later. */
static void ETPad_ToggleMenu_f(void)
{
	/* Use the engine's Escape path, including limbo/console catcher cleanup. */
	Com_QueueEvent(0, SE_KEY, K_ESCAPE, qtrue, 0, NULL);
	Com_QueueEvent(0, SE_KEY, K_ESCAPE, qfalse, 0, NULL);
}
