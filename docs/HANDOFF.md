# ETPad handoff

Goal: native macOS then iPad ET: Legacy, controller first, with original game data kept local and untracked. Full objective is the user's attached goal-objective.md.

Current phase: 1, acceptance item 1, macOS source build. Upstream baseline f49e6db1e54eb292b4abe9e761210bf98522672f. Source build succeeded after explicitly pinning both SDK variables; arm64 modules loaded and Oasis gameplay rendered.

Setup: branch etpad tracks upstream/master. Original origin retained; never push. Simulator guard written before creating the single ETPad iPad; UDID recorded in SIMULATOR.md. An initial read-only simulator inventory was performed directly before the guard existed; all subsequent operations use the guard.

Acceptance:
- macOS source build: verified, docs/evidence/macos/configure.log and build-result.log.
- macOS local rounds, public session/map change/reconnect, controller: not yet done, depend on build and original data.
- iPad launch/download/import/bot/menu/touch/controller/lifecycle: not yet done; phase 1 must finish first.
- iPad device: not yet tested; device and signing inventory pending.
- PadMint build interface and manifest: not yet done.

Failures: initial checkout refused to overwrite untracked .gitignore; preserved and appended it after checkout. Submodule update failed with transport file not allowed for pinned libs commit; explicit HTTPS fetch is next. Simulator init rejected a generic M5 identifier; fixed to installed memory-specific identifier, then created exactly one device.

Latest: source build verified; official original paks hashed, data-only download helper passes Apple Python 3.9. Oasis listen server spawned Allies engineer via console; moved, fired 10 rounds, reloaded, killed/tapped out and respawned. Screenshot oasis-respawn.png. Full-round objective/intermission still pending. In-game mouse clicks did not activate first-run profile or limbo menus in three attempts; console works and gameplay fire works. Initial screenshotPNG command is unsupported; use screenshot with r_screenshotFormat 2.

PadMint check-manifest passes from archived current main 816820206336aefde6de1ada951ff2e0dc438976; scripts/build-etpad.sh interface added but packaging not yet tested. No physical device and zero valid signing identities (2026-11-16).

Next: finish local Oasis/Goldrush rounds and objective evidence, verify main-menu/profile input, public Legacy server ten-minute session with map change/reconnect, controller integration. Phase 2 remains gated on macOS. Last committed source build baseline: 9b7318a94 (documentation only; no engine changes).
