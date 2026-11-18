# App icon

The user selected the 1940s poster portrait on November 17, 2026. It replaces the generic iPad application placeholder and is also used by the Mac app and README. Warm parchment, charcoal, olive and vermilion keep the face readable against the diagonal light shape.

Source: [opaque square master](../apple/Artwork/ETPad-icon-master.png). Mac bundle: [ETPad.icns](../apple/macos/ETPad.icns), generated from the same master with `sips` (16, 32, 128, 256 and 512 points at 1×/2×) and `iconutil`. CMake embeds it in `Contents/Resources` and selects it through `CFBundleIconFile`. The README references the existing 1024-pixel iPad catalog image.

Production sizes: [AppIcon asset catalog](../apple/ios/Host/Assets.xcassets/AppIcon.appiconset). The XcodeGen target selects `AppIcon`; iPadOS applies the corner mask. Sizes are generated from the master using macOS `sips`, without cropping. No original game media is used.

Artwork was created with the built-in imagegen tool. The approved portrait was followed by a corner-extension edit to produce full-bleed square artwork. Prompt direction: an original close-cropped Allied infantry portrait in 1940s screenprinted wartime-poster style, warm parchment highlights, charcoal shadows, olive helmet, vermilion background and a broad cream diagonal searchlight; no text or insignia. Final edit prompt:

> Precise production edit of the supplied approved ETPad app icon. Preserve the existing soldier portrait, face, expression, helmet, uniform, colors, diagonal cream stripe, screenprint texture and composition EXACTLY. Change ONLY the four black areas outside the existing rounded corner artwork: extend the adjacent red poster background / uniform illustration naturally into those corners so the image becomes full-bleed square artwork. Top corners should continue adjacent red background; bottom corners continue adjacent uniform/shoulder artwork. No rounded corner mask, no border, no transparent pixels. Do not redraw or reinterpret the approved central artwork, do not move or resize the subject, do not change any facial features. This is just filling the black external corner wedges for iOS to apply its own system mask. Output a square opaque image.

Validation: default simulator and unsigned device builds pass strict package audits; both compiled app manifests select `AppIcon`. The installed icon is visually verified on the reserved iPad Simulator home screen and dock: [screenshot](evidence/ios-sim/app-icon-home.png). Physical-device installation remains untested.

Mac validation: public build script and strict package audit pass (5 Mach-O binaries, 29 files); exported `CFBundleIconFile` selects `ETPad.icns` and the bundled file is byte-identical to the checked-in ICNS. This is a resource/packaging change; gameplay behavior is unchanged.
