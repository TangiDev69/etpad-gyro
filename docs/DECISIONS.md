# ETPad decisions

## 2026-11-16 — Upstream-first baseline

Context: Empty checkout; macOS must work before iPad. Decision: retain full ET: Legacy master history at f49e6db1e54eb292b4abe9e761210bf98522672f with remote upstream and local branch etpad. Preserve GPL and upstream notices; add Apple integrations under apple/. Evidence: git history and CMakeLists.txt. Reversal: an upstream incompatibility requires a documented pin.

## 2026-11-16 — Reference ports and visual precedence

Context: User specifies GoldenPad/UTP controls although UTP later adopted EctoPad. Decision: follow the user's explicit black translucent resting controls, pressed-only tint and hidden resting guides. Reference checkouts remain read-only. No component copied yet. Read reference commits: sunpad e43f0ea6b797e5110787171957c9dc3c6213269c; utp a9313911efcf044fd66f9a679af53e55e255a8b4; tribespad 3f033e4c4b6a620e8a3cd905565b087adbd2bd0a; goldenpad 54474a40e93b77259d10c7594919e6a05f5e276d; padmint 1d842442a8b309282745531d48c4b8972dd4a6dc. Evidence: UTP docs/DECISIONS.md, TribesPad docs/HANDOFF.md and padmint.json. Reversal: explicit user change or measured physical usability failure.

## 2026-11-16 — One simulator

Context: Memory/thermal constraints. Decision: scripts/sim.sh owns simulator operations, stores one UDID, refuses another booted device, and shuts down after each test. Initialization first attempted a non-existent M5 type (no device created), then selected the installed 16GB identifier. Evidence: docs/SIMULATOR.md. Reversal: only an explicit user change; never create a second ETPad device automatically.
