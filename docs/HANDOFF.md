# ETPad handoff — 2026-11-16

## Read first

Phase 1 is active. Native arm64 macOS client, Legacy modules and renderer build and run from upstream f49e6db1e54eb292b4abe9e761210bf98522672f. iOS implementation has not started; finish or document macOS gates first. No simulator has booted. One device was reserved through scripts/sim.sh (SIMULATOR.md). No other reference checkout was modified. No push, release, tag or catalog edit occurred.

## Acceptance

| Item | Status and evidence |
| --- | --- |
| macOS source build | **verified** — configure.log, build-result.log; current scripted build includes input/network changes |
| macOS main menu | **experimental** — main-menu.png; prepared local profile files permit main menu after restart. Fresh profile name entry and menu clicks fail under CUA; see below |
| macOS local rounds | **experimental, assisted** — Oasis/Goldrush spawned Allies engineer, movement, fire, reload, death/tapout/respawn and timed intermission. Objective capture/pickup used devmap positioning and real triggers. oasis-capture.png, oasis-intermission.png, goldrush-objective.png, goldrush-intermission.png, local-rounds.log. Omni-bot not built; used authorized listen-server fallback |
| macOS public session | **not yet done** — discovery returned 97 servers. First join to 144.76.234.9:27980 hit signed UDP block error at 32 MiB. Fixed parser and retrying. This 1vs1 server needs two players, so switch to a populated/bot-filled server after download boundary validation |
| macOS controller | **experimental** — shared SDL mapping, analog pitch/movement, utility/weapon layers and reconnect cleanup compile. Real SDL virtual-controller test passes (controller-test.log). No physical controller attached/played; no native mapping UI or family prompts yet |
| iPad simulator | **not yet done** — launch, download/import, bot game, complete ellipsis menu, touch layout, prompts, suspend/resume all await engine/host integration |
| iPad device | **not tested: no device or signing** — devicectl finds no physical device; security reports zero valid signing identities |
| PadMint | **experimental** — manifest passes current local main snapshot 816820206336aefde6de1ada951ff2e0dc438976; macOS script/ZIP passes package integrity/media exclusion checks. Device/simulator interface fails explicitly pending iOS implementation. No catalog change |
| Physical iPad feel and networking | **unconfirmed until Chris tests** |

## Current process and first next step

One source-built macOS client is running from build/macos/ET Legacy.app, profile build/profile-macos, console log build/macos/launch-fixed.log. Current public gameplay server: 87.116.30.113:27960 (/GS/Veterans, Legacy v2.84.0, Oasis with ten bots). Joined at about 2026-11-16 16:01 UTC; ten-minute gate ends no earlier than 16:11 UTC. Spawned Allies engineer, moved and fired. Need map change plus disconnect/reconnect. Second server 144.76.234.9:27972 failed with an HTTP 404 for legacy_v2.86.2.pk3; chose an already-cached compatible server. UDP retry completed the 32.71 MiB file and loaded pure-server Oasis; udp-download.log is saved. Then choose a bot-filled Legacy server (discovery snapshot in build/legacy-servers.json; 144.76.234.9:27972 advertised v2.86.2, 16 bots, fueldump, 22-minute limit). Complete ten minutes of play through map change, disconnect/reconnect and save bounded redacted evidence. Keep online play natural; do not send chat or administrative commands.

After public test: rerun local macOS gameplay after input changes; validate package launch paths; commit source/docs. Controller physical acceptance is blocked by absent hardware but component tests can continue. Only then move to iPad host/renderer/static-module integration.

## What failed and what fixed it

- Source attempt 1: linker `tapi error: malformed file`, `unknown architecture arm64e.x1-macos` from CommandLineTools MacOSX27.2 SDK. Attempt 2: CMAKE_OSX_SYSROOT alone overwritten by upstream. Attempt 3: pin both CMAKE_OSX_SYSROOT and XCODE_SDK_PATH to Xcode SDK; build succeeds. Script also exports SDKROOT now; that follow-up needs next build verification.
- Initial submodule update could not fetch pinned historical commit (`transport file not allowed`). Explicit HTTPS fetch + checkout fixed it; build script now has that fallback and requires clean pinned libs.
- Three profile/menu click attempts: direct click+typeText, click+individual keys, held click+held keys all failed to focus/activate game menus. Console and gameplay keyboard/fire work. Prepared `legacy/profiles/ETPadTest/profile.dat` and `legacy/profiles/defaultprofile.dat`, each containing quoted ETPadTest, then restarted to reach main menu. `cl_profile` is read-only; console set cannot apply it. CUA relative drag and Raise did not fix menu movement; further input investigation remains open.
- `screenshotPNG` unsupported; use `set r_screenshotFormat 2` plus `screenshot NAME`. UI catchers consume F12; console `wait 300; screenshot NAME` then close console captures clean UI.
- First public download: expected block 32768, got negative signed shorts. src/client/cl_parse.c now compares low 16 bits while retaining full ACK counter and distinguishes redirect/start/rollover headers. Current running build includes initial fix; duplicate-block-zero handling was refined in source after build and needs next build/test.
- Quit completed engine/network shutdown but process remained sleeping. Terminated the owned old client with SIGTERM before relaunch. No second game client was launched concurrently.
- First simulator type identifier invalid (no device created); installed memory-specific M5 identifier worked. Tracked UDID recovers reservation if build directory is removed, preventing accidental second creation. Initial read-only simulator inventory predated guard; all later sim operations go through it.

## Data, commands and last commit

Original Splash Damage paks and installer remain ignored/local. SHA-256 pins and provenance: GAME_DATA.md. Data-only helper passes Apple Python 3.9.6. Exact build/launch/component-test commands: BUILDING.md. Controller map: CONTROLS.md. Decisions include reference commits; no port component has been copied yet.

Last committed checkpoint before upcoming controller/network commit: 2a1a1f253. Current controller/network/package/source and evidence updates are uncommitted pending live network validation. Do not commit original data, saves or builds. Build output remains under build/, at half the eight CPU cores. Never build twice in parallel or run simulator alongside game.
