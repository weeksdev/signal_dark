# Agent Tooling

This folder contains the screenshot workflow for agent-driven visual debugging.

## What It Does

`capture-screenshots.sh` boots the real project through Godot, loads full game scenes through the project autoloads, waits for scene setup to settle, and saves a review bundle with:

- `*.png` screenshots
- `manifest.json` capture metadata
- `index.html` thumbnail review page

It supports:

- title menu capture
- story zone capture
- stepped ship-route capture through the first story map into the next room
- arcade capture across multiple seeds and difficulties

## Usage

Smoke test:

```bash
./agent-tooling/capture-screenshots.sh --smoke
```

Default full run:

```bash
./agent-tooling/capture-screenshots.sh
```

Arcade only:

```bash
./agent-tooling/capture-screenshots.sh --mode arcade
```

Custom story scenes:

```bash
./agent-tooling/capture-screenshots.sh \
  --mode story \
  --story-scenes res://src/world/World.tscn,res://src/world/World03.tscn
```

Custom arcade sweep:

```bash
./agent-tooling/capture-screenshots.sh \
  --mode arcade \
  --arcade-seeds 42424,51515,62626 \
  --arcade-difficulties easy,hardcore
```

Custom output directory:

```bash
./agent-tooling/capture-screenshots.sh --output-dir review_batch_a

Final presented-frame capture on macOS:

```bash
./agent-tooling/capture-screenshots.sh \
  --capture-backend screen \
  --output-dir final_frame_batch
```
```

## Output

By default outputs land under:

```text
agent-tooling/output/session_<timestamp>/
```

Open `index.html` in that folder to review the captured batch quickly.

## Notes

- This is intentionally not `--headless`; it captures the rendered viewport.
- `--smoke` captures a minimal set quickly for tool verification.
- The first story scene captures multiple checkpoints from spawn to the next room so you can review camera framing, enemy pressure, and HUD state while advancing.
- The runner uses real scene transitions instead of instantiating partial scenes directly.
- Default capture backend is `viewport`, which is automation-safe but can miss some final screen-texture composition.
- `--capture-backend screen` captures the presented game window instead, but on macOS it requires Screen Recording permission for the terminal process and can include the cursor or system permission prompts until granted.
