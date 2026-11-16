# Building ETPad

Experimental macOS baseline; iOS not yet implemented. Xcode 26.6, Apple arm64, CMake and Ninja. All commands run from this repository.

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
cmake -S . -B build/macos -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 -DINSTALL_EXTRA=OFF -DFEATURE_AUTOUPDATE=OFF
cmake --build build/macos -j$(( $(sysctl -n hw.ncpu) / 2 ))
```

Configure/build logs live in build/macos. Original data acquisition and verified hashes: GAME_DATA.md. No original game media belong in a build artifact.

The one reserved simulator is documented in SIMULATOR.md. Every simulator operation uses scripts/sim.sh. Never run macOS game and simulator together, or two builds in parallel.
