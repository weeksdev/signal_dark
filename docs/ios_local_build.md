# iPhone Local Build

Last updated: 2026-04-25

## Current Setup

The repo now includes:

- `export_presets.cfg` with an `iOS` export preset
- `build-ios.sh` as the repo-root iPhone export entry point
- `build-macos.sh` as the repo-root macOS dev build/run entry point
- `tasks/export_ios_local.sh` to generate an Xcode project locally
- mobile orientation defaulted to landscape in `project.godot`

This setup is intentionally minimal:

- it exports an Xcode project
- it does not try to produce a signed `.ipa` directly
- signing stays in your local machine/Xcode flow
- it uses debug export by default for local device testing
- it does not archive/sign inside Godot; that happens in Xcode

## Prerequisites

You need:

- Godot 4.5.1 with iOS export templates installed
- Xcode installed
- a connected iPhone
- an Apple signing team available in Xcode

## Local Export

From the repo root, the simplest path is:

```bash
./build-ios.sh
```

That uses these defaults:

- Team ID: `XQ9D888PGU`
- Bundle ID: `com.andrewweeks.signaldark.dev`
- Export root: `/tmp/signal_dark_build`

If you want to override the bundle identifier for a different device/install, use:

```bash
SIGNAL_DARK_IOS_BUNDLE_ID=com.yourname.signaldark.test \
./build-ios.sh
```

Notes:

- `build-ios.sh` sets `SIGNAL_DARK_IOS_TEAM_ID` to your Team ID by default
- `SIGNAL_DARK_IOS_BUNDLE_ID` defaults to `com.andrewweeks.signaldark.dev` if omitted
- `SIGNAL_DARK_IOS_EXPORT_ROOT` defaults to `/tmp/signal_dark_build`
- the script restores the committed `export_presets.cfg` after export, so your local values are not left in the repo
- verbose export logs are written to `/tmp/signal_dark_build/ios/export-ios.log`
- local iPhone testing defaults to `debug`; set `SIGNAL_DARK_IOS_EXPORT_KIND=release` only if you explicitly want release export behavior
- the export is intentionally outside the Godot project root so generated Xcode assets do not get imported as `res://` content

## Open In Xcode

After export:

1. Open `/tmp/signal_dark_build/ios/SignalDark.xcodeproj` in Xcode.
2. Select the project target.
3. Sign in with the Apple account you want to use if Xcode is not already logged in.
4. Set your signing team.
5. Confirm the bundle identifier is unique for your Apple account.
6. Choose the connected iPhone as the run destination.
7. Build and run.

## Current Simulator Caveat

On Apple-silicon Macs, the generated Godot 4.5.1 simulator XCFramework can still fail with:

- `Undefined symbol: _main`

That is a simulator-slice issue in the exported `libgodot.a`, not an iPhone device build issue. The local validation path that matters for this repo is:

- export Xcode project with `./build-ios.sh`
- open the generated project in Xcode
- sign with your Apple account/team
- run on a physical iPhone

If export fails:

1. Open `/tmp/signal_dark_build/ios/export-ios.log`
2. Copy the last 100-150 lines
3. Use that log instead of the short terminal error, because Godot often hides the actual iOS preset validation details in the default console output

## Expected First Goal

This first build path is only meant to prove:

- the project exports cleanly to Xcode
- the game launches on iPhone
- landscape orientation is correct
- we can test with and without controller

It is not yet the final App Store packaging flow.
