# Performance

The November 17 native-host pass reduces redundant work while preserving the existing renderer, visual settings, 60 Hz display scheduling and per-frame HUD polling. This is a small host optimization; it does not establish a physical-iPad FPS or battery improvement.

## What changed

- Cache launch mode and controller membership. Refresh controller state on initialization, connection/disconnection, app activation and window-key notifications.
- Reuse the completed gameplay-state snapshot during UIKit layout, avoiding engine queries inside SDL's nested UIKit loop.
- Update view frames, visibility and Metal drawable scale only when their values change. Keep dimension checks and release held touch inputs on hide transitions.
- Log native host and whole-callback elapsed times alongside engine timing, making their relative costs visible.

A five-second main-thread sample places the dominant work in rendering through GLES/GL4ES/ANGLE. This pass does not attempt an unverified renderer rewrite or disable graphics validation.

## Measurement — November 17, 2026

M2 MacBook Air, reserved iPad Pro 11-inch Simulator, iOS 26.5, default ANGLE/GL4ES Metal path, requested surface **1280×882**. Both apps use the same timing instrumentation and build pipeline. Baseline: `0c2bc9049` plus instrumentation; optimized: `a40f4ad01` (native-host changes). One simulator, no Mac game, no builds or sampling during selected windows.

Local Oasis, no active bots, stationary spectator camera at `setviewpos 3708 7352 -480 180`, after warmup. Touch controls visible, same reported controller membership, native menus/scoreboard closed. Each result is the median of three separate 600-frame windows (1,800 frames per build). Selected raw lines and timestamps: [performance-host.txt](evidence/performance-host.txt). Screenshots: [baseline](evidence/ios-sim/performance-baseline.png), [optimized](evidence/ios-sim/performance-optimized.png).

| Elapsed time, milliseconds | Baseline | Optimized |
| --- | ---: | ---: |
| Native host mean per window | 0.060 | 0.008 |
| Native host p95 per window | 0.113 | 0.016 |
| Engine mean per window | 3.255 | 3.189 |
| Complete callback mean per window | 3.318 | 3.197 |
| Complete callback p95 per window | 4.477 | 4.444 |
| Display callback interval mean | 16.667 | 16.667 |

Native-host window means range 0.058–0.064 ms before and 0.008–0.009 ms after. That is about **0.052 ms less host work per callback** in this scene. Engine means vary 3.253–3.285 ms before and 3.061–3.282 ms after; do not attribute that variation to a renderer speedup. The display cadence remains 60 Hz.

These are elapsed main-thread wall durations, not CPU utilization or GPU completion times. Aggregation/sorting/logging occur after the measured callback boundary. The test is sequential, short and simulator-specific, with an idle scene rather than combat. Thermal state and system scheduling are uncontrolled; there is no repeated randomized A/B trial. Do not extrapolate the host percentage reduction to total frame performance, physical-device power use or touch latency. See [BUILDING.md](BUILDING.md#performance-diagnostics) for field definitions and collection guidance.

## Regression scope and next measurements

The optimized default simulator build passes strict package/signature checks. Native Console, organized menu, scoreboard hide/restoration, controller auto-hide, resolution restart, landscape and resume checks cover the changed host behavior. Package revalidation is recorded in [HANDOFF.md](HANDOFF.md).

Earlier public map-rotation/reconnect and assisted bot-round evidence remains linked from HANDOFF. Optional Vulkan gameplay observations are exploratory, with differing game state and swapchain sizes; they are not a controlled comparison against ANGLE. ANGLE remains default.

Next useful performance work requires a signed physical iPad: sustained combat on a repeatable map/demo, frame/GPU traces, thermal behavior and touch/controller latency. Physical installation, multi-touch ergonomics and controller/keyboard/trackpad feel remain untested without hardware/signing.
