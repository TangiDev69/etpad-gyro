# Building ETPad

Experimental macOS and iOS builds. Xcode 26.6, Apple arm64, CMake and Ninja. All commands run from this repository.

```sh
git config submodule.libs.url https://github.com/etlegacy/etlegacy-libs.git
git submodule update --init libs
```

If the initial shallow submodule checkout cannot obtain the pinned commit:

```sh
git -C libs fetch origin 6bf44adf4781a49713a1c81ba5de3bd0165339c5
git -C libs checkout 6bf44adf4781a49713a1c81ba5de3bd0165339c5
```

```sh
cmake -S . -B build/macos -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 -DCMAKE_OSX_SYSROOT="$(xcrun --sdk macosx --show-sdk-path)" -DXCODE_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)" -DINSTALL_EXTRA=OFF -DFEATURE_AUTOUPDATE=OFF
cmake --build build/macos -j$(( $(sysctl -n hw.ncpu) / 2 ))
```

Configure/build logs live in build/macos. Original data acquisition and verified hashes: GAME_DATA.md. No original game media belong in a build artifact.

The one reserved simulator is documented in SIMULATOR.md. Every simulator operation uses scripts/sim.sh. Never run macOS game and simulator together, or two builds in parallel.

## Current entry points

```sh
/usr/bin/python3 scripts/prepare-game-data.py --download
# Or: /usr/bin/python3 scripts/prepare-game-data.py --import-from /path/to/etmain
scripts/build-etpad.sh --platform macos --output build/output --zip build/output/ETPad-mac.zip
```

The macOS package contains the source-built app, renderer, Legacy native modules and GPL mod pack. Its upstream native-module entries must be byte-identical to the corresponding separately exported source-built modules; other native archive entries are rejected. The iPad Legacy pack is data-only. It excludes original pak0/1/2. The default simulator app embeds five engine/module frameworks plus the source-built ETPadOmnibot.framework, with ad hoc signatures, and ANGLE. The fresh bot-enabled device app/IPA is unsigned; its strict package audit passes, but installation requires signing.

Local baseline launch (after copying owned paks into build/macos/etmain):

```sh
'build/macos/ET Legacy.app/Contents/MacOS/ET Legacy' +set fs_basepath "$PWD/build/macos" +set fs_homepath "$PWD/build/profile-macos" +set fs_game legacy +set r_fullscreen 0 +set r_mode -1 +set r_customwidth 1024 +set r_customheight 768 +set com_introplayed 1 +set logfile 2
```

Exported-app launch, verified in the resumed Mac bot regression (originals stay in a separate writable home):

```sh
mkdir -p build/profile-macos/etmain
cp game-data/etmain/pak[012].pk3 build/profile-macos/etmain/
'build/output/ETPad-mac/ET Legacy.app/Contents/MacOS/ET Legacy' +set fs_basepath "$PWD/build/output/ETPad-mac" +set fs_homepath "$PWD/build/profile-macos" +set fs_game legacy +set r_fullscreen 0 +set r_mode -1 +set r_customwidth 1024 +set r_customheight 768 +set com_introplayed 1 +set logfile 2
```

For the bot regression, append `+exec etpad-bots.cfg +devmap oasis +bot maxbots 4` after creating the optional local bot setup below. The home/profile and original paks are excluded from all exports.

Component controller test (Homebrew SDL2 development headers/library):

```sh
xcrun clang -isysroot "$(xcrun --sdk macosx --show-sdk-path)" tests/apple/controller_layers.c -I/opt/homebrew/include/SDL2 -L/opt/homebrew/lib -lSDL2 -o build/tests/controller_layers
build/tests/controller_layers
```

PadMint validation against a read-only snapshot of current local main:

```sh
mkdir -p build/padmint-main
git -C /Users/chrissotraidis/GitHub/padmint archive main | tar -x -C build/padmint-main
(cd build/padmint-main && python3 -m padmint check-manifest /Users/chrissotraidis/GitHub/etpad)
```

Local assisted gameplay commands: `map oasis`, `team b 2 8`, `forcetapout`; bind normal movement/fire/reload; `kill`, `forcetapout`; `set timelimit 2`. Objective-specific developer tests: `devmap oasis`, `setviewpos 3708 7352 -480 0`, then move forward into the flag; `devmap goldrush`, `setviewpos 2478 -2248 -280 0` to test gold pickup. For screenshots set `r_screenshotFormat 2` and use `screenshot NAME`; in a UI catcher run `wait 300; screenshot NAME`, then close the console. These assisted tests are not unassisted map traversal or physical input validation.

## Local native bots (macOS)

```sh
scripts/prepare-bots.sh
scripts/build-etpad.sh --platform macos --output build/output
```

The macOS build enables the source-built Legacy Omni-bot interface. The optional bot core is the official ET: Legacy mirror's Omni-bot 0.93 universal macOS binary, including arm64, extracted only under ignored build/omnibot-runtime. It is not included in the package. This is separate from the source-built engine and game module.

Launch with the baseline command above plus:

```sh
+set omnibot_enable 1 +set omnibot_path "$PWD/build/omnibot-runtime/omni-bot" +set g_minGameClients 2 +set g_gametype 2 +devmap oasis
```

Console: `bot maxbots 4` (three bots plus the player), `team b 2 8`. After the warmup restart announces FIGHT, set `timelimit 2` again because the map script resets its time limit at round start. Use Goldrush in the same way. Objective positioning remains an explicitly assisted developer test. Gameplay input was driven through CUA, not a physical controller.

## iOS host and simulator

```sh
scripts/build-etpad.sh --platform simulator --output build/output
ETPAD_SIM_VISIBLE=1 ETPAD_SIM_HOLD_SECONDS=1800 scripts/sim.sh test "$PWD/build/output/ETPad-simulator.app" com.chrissotraidis.etpad --etpad-oasis
# In a second terminal, end the bounded block early:
touch build/simulator-stop
# Device build (unsigned; not an installable signed release):
scripts/build-etpad.sh --platform device --output build/output --ipa build/output/ETPad-unsigned.ipa
```

XcodeGen is required. Driver pins ANGLE binary inputs and builds GL4ES plus native engine/modules. All Python helpers support Apple Python 3.9. Logs and dependency sources remain under build/. Use `--etpad-host-only` instead of `--etpad-oasis` for acquisition/settings tests; the Play button still starts the engine. With no argument, verified installed data auto-starts the main menu. Native Console accepts the local assisted commands above. Source-built iOS Omni-bot integration now has an assisted simulator round through timed intermission; setup and remaining limits are below.

Simulator Device → Orientation → Landscape Right/Left sets the sensor; the toolbar Rotate alone can rotate the bezel without updating it. Screenshot raw framebuffers may be portrait with rotated content. Only the documented saved UDID is used. Data can be acquired in the actual app, or optionally staged as a hash-checked local fixture with ETPAD_SIM_DATA_DIR=/path/to/etmain. It is never staged into exported apps.


## Personal iPad install (development signing)

With Xcode signed in to your team, sign the device app and install it on a paired iPad:

```sh
ETPAD_TEAM=YOURTEAMID scripts/build-etpad.sh --platform device --output build/output
xcrun devicectl device install app --device <UDID> build/output/ETPad-device.app
```

`ETPAD_BUNDLE_ID` overrides `com.chrissotraidis.etpad` if that identifier is unavailable to your team. Signed builds cannot produce `--ipa`; public IPAs stay unsigned. The package audit accepts the root `embedded.mobileprovision` only for these signed builds.

Launch hooks for testing on hardware (they run the same code as the launcher buttons):

```sh
xcrun devicectl device process launch --device <UDID> --terminate-existing com.chrissotraidis.etpad --etpad-practice oasis --etpad-command 'team b 2 8;openlimbomenu'
xcrun devicectl device process launch --device <UDID> --terminate-existing com.chrissotraidis.etpad --etpad-servers
xcrun devicectl device process launch --device <UDID> --terminate-existing com.chrissotraidis.etpad --etpad-connect host:27960
```

Copy verified paks into a fresh install without tapping: `xcrun devicectl device copy to --device <UDID> --source game-data/etmain/pak0.pk3 --destination Documents/ETPad/etmain/pak0.pk3 --domain-type appDataContainer --domain-identifier com.chrissotraidis.etpad` (repeat for pak1/pak2). `xcrun devicectl device capture screenshot` grabs the screen.

## Building on a second Mac (Xcode 27.2, 2026-11-18)

A clean clone built device, simulator and the signed app on Xcode 27.2 with no source changes; the 712 compiler warnings are all upstream or third-party (Omni-bot, Boost, GL4ES, SDL). The first device build fetches Omni-bot, Boost, GL4ES, SDL and ANGLE inputs, so it needs network access. Problems found and fixed:

- `scripts/sim.sh` read a simulator UDID recorded on the other Mac and created devices with a hard-coded iOS 26.5 runtime. The reservation is now per machine in ignored `build/simulator-udid`, and `init` uses the newest installed iOS runtime.
- Xcode 27 renames Simulator.app to DeviceHub.app, so `open -a Simulator` failed and the guarded test exited. `sim.sh` now falls back to DeviceHub.
- The device package audit rejected development-signed apps because of `embedded.mobileprovision`; signed builds now pass `--allow-development-profile`.
- Computer Use could not drive DeviceHub on this Mac (it times out), so interactive checks used the physical iPad with the launch hooks above.


## Local native bots (iPad)

The iOS build automatically builds the pinned Omni-bot core and embeds it as `ETPadOmnibot.framework`. The loader accepts only this exact bundled framework path. Bot script/navigation data comes from the hash-verified official Omni-bot 0.93 distribution; the distribution's downloaded native executable is excluded. Generated bot configuration/navigation stays in the writable app sandbox, outside the signed framework.

Source pins and private build patches live in [`scripts/build_omnibot.py`](../scripts/build_omnibot.py): Omni-bot `b3f10f334de625765100bbfeacc5eac95c098607`, GameMonkey `2d24f6e500c327aa2e99f3572e8e2f4b285e37f4`, and hash-verified Boost 1.85.0. Sources, dependency builds and receipts remain under ignored `build/`; script/navigation archive downloads remain under ignored `downloads/`. Notices are included in the framework.

After acquiring verified original game data and starting the engine, open the native three-dot menu → **Console…** and run:

```text
set omnibot_enable 1; devmap oasis
```

After the local map loads, open Console again:

```text
bot maxbots 4
```

Use **Game Menu** or the touch MENU button to open Limbo, choose Allies, select the engineer wrench and confirm **OK**. The simulator test loaded core version 0.93, produced four active Oasis bots, selected engineer on the first tap, fired from 30 to 25 rounds and reloaded to 30/25 ammunition, then encountered a bot kill at the objective. After the bot kill, `forcetapout` and respawn returned the engineer at 110 HP. Objective interaction then used `god`, `setviewpos` and forward movement to capture Old City (5 XP), and a reduced time limit produced AXIS WIN intermission. This verifies an assisted round, not unassisted traversal or physical input. Evidence: [bot-round log](evidence/ios-sim/bots-resumed.log), [respawn/objective](evidence/ios-sim/bots-respawn-objective.png) and [intermission](evidence/ios-sim/bots-intermission.png). No physical iPad or physical-controller acceptance is claimed. The final macOS shared-guard repeat, refreshed default ANGLE UI/package checks and bot-enabled unsigned device build/audit also pass; see [final package audit](evidence/package-resumed.txt). Optional Vulkan simulator runtime and strict package audit now pass, as described below.


## Optional Vulkan/MoltenVK simulator renderer

ANGLE/GL4ES remains the default. To build the optional source-built Vulkan renderer and MoltenVK simulator variant:

```sh
ETPAD_RENDERER=vulkan scripts/build-etpad.sh --platform simulator --output build/output
ETPAD_SIM_VISIBLE=1 ETPAD_SIM_HOLD_SECONDS=1800 \
  scripts/sim.sh test "$PWD/build/output/ETPad-simulator-vulkan.app" \
  com.chrissotraidis.etpad --etpad-vulkan --etpad-oasis
```

This variant embeds ETPadVulkanRenderer.framework and MoltenVK.framework alongside the default engine/bot/ANGLE frameworks. Its strict package audit passes architectures/platforms, bundled/system dependencies, runtime search paths, signatures, notices and media exclusions. The source-built bot core and its script/navigation setup are the same as above. Device Vulkan runtime is not tested.

The first resumed runtime produced a magenta screen because the simulator's Apple2 feature set rejected nonzero base-vertex draws. The iOS vertex-binding-offset fallback then rendered full Oasis with active local bots, native touch MENU → Limbo/team/class/OK, engineer fire 25/30 and reload 30/25, with no VK_ERROR in the accepted log. Evidence: [accepted runtime log](evidence/ios-sim/vulkan-resumed.log), [Oasis screenshot](evidence/ios-sim/vulkan-oasis.png), and the retained [first failure log](evidence/ios-sim/vulkan-resume-attempt1.log) / [screenshot](evidence/ios-sim/vulkan-resume-failure1.png).

Selected steady spectator windows recorded CPU means 2.660–3.621 ms, p95 3.541–5.172 ms and display intervals 16.667–16.722 ms. Selected steady engineer/bot windows recorded CPU means 6.784–11.491 ms, p95 15.409–29.693 ms and intervals 16.858–18.809 ms; the initial team-entry transition is excluded. The scene was logically 1280×882 while the actual MoltenVK swapchain was 1210×834. Earlier ANGLE windows used a different gameplay state and surface configuration. These observations are not a matched controlled benchmark, a physical-device performance guarantee or a renderer-winner claim.


## Read-only package audit

Run after exporting an app/package; these checks do not build, launch, sign or modify the artifact:

```sh
/usr/bin/python3 scripts/check-apple-package.py --platform macos build/output/ETPad-mac
/usr/bin/python3 scripts/check-apple-package.py --platform simulator build/output/ETPad-simulator.app
/usr/bin/python3 scripts/check-apple-package.py --platform simulator build/output/ETPad-simulator-vulkan.app
/usr/bin/python3 scripts/check-apple-package.py --platform device build/output/ETPad-device.app
```

The Mac command takes the whole package directory, including its app and separate renderer/modules. iOS commands take an exported `.app`, not an IPA. Mac PK3 native entries must match the separately exported own modules byte for byte; iOS PK3 files must be data-only. Device signatures are not required by this audit, so passing it does not establish installability or physical-device runtime acceptance.

## Public iPad Simulator rotation regression

Use the single guarded simulator for a bounded hour when a public round can last 30 minutes:

```sh
ETPAD_SIM_VISIBLE=1 ETPAD_SIM_HOLD_SECONDS=3600 \
  scripts/sim.sh test "$PWD/build/output/ETPad-simulator.app" com.chrissotraidis.etpad
```

Set Device → Orientation → Landscape Right/Left. In native **Tools → Console**, run `connect 87.116.30.113:27960`; select a team/class and exercise movement, Fire and Reload. Let the server change maps normally. After the second map loads, exercise gameplay again, then run `disconnect;wait 120;reconnect`. Here `wait 120` means engine frames, not 120 seconds. Re-select team/class and confirm gameplay again without restarting the app. Do not send votes, chat, admin or server-configuration commands. End with `touch build/simulator-stop`. The wrapper accepts 10–3600 seconds and always shuts down/quits the same reserved simulator.

The 2026-11-16 baseline run passed Railgun → Fuel Dump, post-transition movement/fire/reload, and explicit disconnect/reconnect followed by first-tap team/class spawn and Fire, all in PID 92902. [Continuous log](evidence/ios-sim/public-rotation.log), [new-map gameplay](evidence/ios-sim/public-rotation-fueldump.png), [reconnected gameplay](evidence/ios-sim/public-rotation-reconnected.png). This is simulator Legacy-server coverage; physical iPad networking and general server/mod compatibility remain unconfirmed.

The final HUD-placement build repeats public Fuel Dump → Oasis rotation and post-transition reconnect in PID 1258: [final-build log](evidence/ios-sim/public-placement-final.log). Combat controls restore after the round-end scoreboard/new map; the iOS grid cache recomputes for the new span.


## Performance diagnostics

Every 600 active engine frames, the iOS host logs `ETPad TIMING`. `cpu_avg_ms` / `cpu_p95_ms` retain their historical field names but measure elapsed `etpad_frame()` wall time, not CPU utilization. `host_*` measures callback work outside that engine call; `callback_*` covers both. `interval_avg_ms` measures display-callback spacing, including stalls and suspension gaps. Aggregation/sorting/log emission follows the measured callback boundary and is excluded from its duration. Dimensions identify the requested render surface, not every backend's physical swapchain size.

Collect steady windows after loading, notifications and warmup finish. Match map, camera, renderer, resolution, HUD/controller state and build configuration; record the selected windows and preserve screenshots. Avoid builds, sampling and UI automation during the measurement itself. [PERFORMANCE.md](PERFORMANCE.md) records the current pass and limits. Simulator timings cannot establish iPad FPS, power use, thermal behavior or input latency.
