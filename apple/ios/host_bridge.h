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
