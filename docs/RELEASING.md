# Releasing ETPad

A release publishes an unsigned iPad IPA and the recipe PadMint builds from. The
original game data is never included.

## Before publishing

1. Merge the release work to `main` and build from a clean `main` checkout:

   ```sh
   scripts/build-etpad.sh --platform device --output build/output \
     --ipa build/output/ETPad-unsigned.ipa
   ```

2. Every public file passes PadMint's audit (and the private release gate):

   ```sh
   cd /path/to/padmint
   python3 -m padmint audit /path/to/etpad/build/output/ETPad-unsigned.ipa
   ```

3. PadMint player check from PadMint's current `main` (plus the ETPad catalog
   entry), with the clean checkout:

   ```sh
   scripts/player-check.sh etpad ios - /path/to/etpad
   ```

4. Install the exact IPA in place on a physical iPad, download the game data,
   and play a bot round and a public server.
5. Bump `CFBundleShortVersionString` and `CFBundleVersion` in
   `apple/ios/Host/project.yml`, update the README badge and notes, and write
   `docs/releases/vX.Y.Z.md`.
6. Create a draft GitHub release for `vX.Y.Z` targeting `main`, marked as a
   pre-release, with `ETPad-unsigned.ipa`, `padmint.json` attached as
   `ETPad-vX.Y.Z-padmint.json`, and a `SHA256SUMS` file listing both. PadMint
   only builds a release that publishes its recipe this way.

The ET: Legacy workflows inherited from upstream (ETLBuild, CI, Coverity Scan,
Snapcraft) are disabled in this repository's Actions settings. ETLBuild runs on
`v*` tags and would try to publish ET: Legacy packages, so keep it disabled.

## Publishing (owner only)

1. Review and publish the draft release. Publishing creates the tag.
2. Merge the PadMint catalog entry and release PadMint.
3. Run the player check again without a checkout, the way players build it:

   ```sh
   scripts/player-check.sh etpad ios -
   ```

   A failure blocks the announcement.
4. Announce.
