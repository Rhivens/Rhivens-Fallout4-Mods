# Changelog — Wash That Body

## 0.2.2

- Fixed a crash that could occur when the cleanup hotkey was pressed.
- Added NiRTTI hierarchy validation before treating a named scene-graph object as a `BGSDecalNode`.
- Confirmed cleanup of front and back player blood decals.
- Confirmed preservation of tattoos, makeup, tints and body overlays.
- Confirmed that nearby NPCs are not cleaned.
- Validated repeated hotkey use in game.
- Built for Fallout 4 OldGen 1.10.163 and F4SE 0.6.23.

## 0.2.1

- Added full player scene-graph traversal for blood decal cleanup.
- Known issue: identifying decal nodes by name alone could select a regular `NiNode` and cause a crash.
- Superseded by version 0.2.2.
