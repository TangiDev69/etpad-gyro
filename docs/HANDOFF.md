# ETPad handoff

Goal: native macOS then iPad ET: Legacy, controller first, with original game data kept local and untracked. Full objective is the user's attached goal-objective.md.

Current phase: 1, acceptance item 1, macOS source build. Upstream baseline f49e6db1e54eb292b4abe9e761210bf98522672f. No verified game build yet.

Setup: branch etpad tracks upstream/master. Original origin retained; never push. Simulator guard written before creating the single ETPad iPad; UDID recorded in SIMULATOR.md. An initial read-only simulator inventory was performed directly before the guard existed; all subsequent operations use the guard.

Acceptance:
- macOS source build: not yet done; dependencies being initialized.
- macOS local rounds, public session/map change/reconnect, controller: not yet done, depend on build and original data.
- iPad launch/download/import/bot/menu/touch/controller/lifecycle: not yet done; phase 1 must finish first.
- iPad device: not yet tested; device and signing inventory pending.
- PadMint build interface and manifest: not yet done.

Failures: initial checkout refused to overwrite untracked .gitignore; preserved and appended it after checkout. Submodule update failed with transport file not allowed for pinned libs commit; explicit HTTPS fetch is next. Simulator init rejected a generic M5 identifier; fixed to installed memory-specific identifier, then created exactly one device.

Next: finish dependency initialization, configure arm64 macOS release with Legacy mod, build at four jobs, download and hash official pak data, run main menu then local rounds.
