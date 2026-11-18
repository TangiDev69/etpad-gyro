// GPL-3.0-or-later
#pragma once
int etpad_engine_main(int argc, char **argv);
void etpad_command(const char *command);
void etpad_key(int key, int down);
void etpad_mouse(int dx, int dy);
void etpad_release_inputs(void);

void etpad_frame(void);
void *etpad_render_window(void);
int etpad_extract_official(const char *archive, const char *directory);
int etpad_gameplay(void);
// Bit 1: scoreboard requested/rendered; bit 2: snapshot is intermission.
int etpad_hud_flags(void);
const char *etpad_renderer(void);
int etpad_render_width(void);
int etpad_render_height(void);
void etpad_touch_move(float side, float forward);
void etpad_pointer(float x, float y, int edge);
void etpad_hardware_key(int usage, int down);

void etpad_character(int codepoint);
void etpad_set_pointer_locked(int locked);
void etpad_set_suspend_look(int suspend);
int etpad_take_mouse_activity(void);
int etpad_client_state(void);
int etpad_local_server(void);
