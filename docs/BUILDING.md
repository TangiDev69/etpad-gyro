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

The macOS package contains the source-built app, renderer, Legacy native modules and GPL mod-data pack. It excludes original pak0/1/2. The simulator app embeds five ad hoc signed native frameworks and ANGLE. The device output is unsigned until a signing identity is available.

Local baseline launch (after copying owned paks into build/macos/etmain):

```sh
'build/macos/ET Legacy.app/Contents/MacOS/ET Legacy' +set fs_basepath "$PWD/build/macos" +set fs_homepath "$PWD/build/profile-macos" +set fs_game legacy +set r_fullscreen 0 +set r_mode -1 +set r_customwidth 1024 +set r_customheight 768 +set com_introplayed 1 +set logfile 2
```

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

XcodeGen is required. Driver pins ANGLE binary inputs and builds GL4ES plus native engine/modules. All Python helpers support Apple Python 3.9. Logs and dependency sources remain under build/. Use `--etpad-host-only` instead of `--etpad-oasis` for acquisition/settings tests; the Play button still starts the engine. With no argument, verified installed data auto-starts the main menu. Native Console accepts the local assisted commands above. Bot integration on iOS is pending.

Simulator Device → Orientation → Landscape Right/Left sets the sensor; the toolbar Rotate alone can rotate the bezel without updating it. Screenshot raw framebuffers may be portrait with rotated content. Only the documented saved UDID is used. Data can be acquired in the actual app, or optionally staged as a hash-checked local fixture with ETPAD_SIM_DATA_DIR=/path/to/etmain. It is never staged into exported apps.
