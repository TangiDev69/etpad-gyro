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

The macOS package contains the source-built app, renderer, Legacy native modules and GPL mod-data pack. It excludes original pak0/1/2. The default simulator app embeds five engine/module frameworks plus the source-built ETPadOmnibot.framework, with ad hoc signatures, and ANGLE. Earlier device output is unsigned until a signing identity is available; a fresh bot-enabled device build/package check is pending.

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
ETPAD_SIM_VISIBLE=1 ETPAD_SIM_HOLD_SECONDS=1800 scripts/sim.sh test "$PWD/build/output/ETPad-simulator.app" com.etpad.ETPad --etpad-oasis
# In a second terminal, end the bounded block early:
touch build/simulator-stop
# Device build (unsigned; not an installable signed release):
scripts/build-etpad.sh --platform device --output build/output --ipa build/output/ETPad-unsigned.ipa
```

XcodeGen is required. Driver pins ANGLE binary inputs and builds GL4ES plus native engine/modules. All Python helpers support Apple Python 3.9. Logs and dependency sources remain under build/. Use `--etpad-host-only` instead of `--etpad-oasis` for acquisition/settings tests; the Play button still starts the engine. With no argument, verified installed data auto-starts the main menu. Native Console accepts the local assisted commands above. Source-built iOS Omni-bot integration now has an assisted simulator round through timed intermission; setup and remaining limits are below.

Simulator Device → Orientation → Landscape Right/Left sets the sensor; the toolbar Rotate alone can rotate the bezel without updating it. Screenshot raw framebuffers may be portrait with rotated content. Only the documented saved UDID is used. Data can be acquired in the actual app, or optionally staged as a hash-checked local fixture with ETPAD_SIM_DATA_DIR=/path/to/etmain. It is never staged into exported apps.


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

Use **Game Menu** or the touch MENU button to open Limbo, choose Allies, select the engineer wrench and confirm **OK**. The simulator test loaded core version 0.93, produced four active Oasis bots, selected engineer on the first tap, fired from 30 to 25 rounds and reloaded to 30/25 ammunition, then encountered a bot kill at the objective. After the bot kill, `forcetapout` and respawn returned the engineer at 110 HP. Objective interaction then used `god`, `setviewpos` and forward movement to capture Old City (5 XP), and a reduced time limit produced AXIS WIN intermission. This verifies an assisted round, not unassisted traversal or physical input. Evidence: [bot-round log](evidence/ios-sim/bots-resumed.log), [respawn/objective](evidence/ios-sim/bots-respawn-objective.png) and [intermission](evidence/ios-sim/bots-intermission.png). No physical iPad or physical-controller acceptance is claimed. The fresh macOS shared-code regression, bot-enabled device build, package audit and Vulkan runtime comparison remain pending.
