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
const char *etpad_renderer(void);
int etpad_render_width(void);
int etpad_render_height(void);
void etpad_touch_move(float side, float forward);
void etpad_pointer(float x, float y, int edge);
void etpad_hardware_key(int usage, int down);

void etpad_character(int codepoint);
