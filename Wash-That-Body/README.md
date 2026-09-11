# Wash That Body – Player Blood Cleaner

**Wash That Body** is a lightweight F4SE plugin that manually removes blood decals from the player character without cleaning nearby NPCs or removing tattoos, makeup, tints, or body overlays.

## Status

- Version: **0.2.2**
- Status: **tested successfully in game**
- Runtime: **Fallout 4 OldGen 1.10.163**
- F4SE: **0.6.23**
- Next-Gen support: **not available in this build**

## Features

- Removes blood decals from the player's entire body.
- Handles both first-person and third-person character models.
- Clears equipped-weapon blood effects and screen splatter.
- Does not clean blood from NPCs.
- Preserves tattoos, makeup, tints, mascara effects, and body overlays.
- Manual hotkey; no automatic cleanup on save loading.
- No ESP, Papyrus script, quest, MCM, or external cleaning plugin.

## Requirements

- Fallout 4 **1.10.163**
- F4SE **0.6.23**

**Wash That Blood Off is not required.** No DLL or asset from that mod is included.

Tested v0.2.2 binary:

- file size: **546,816 bytes**;
- SHA-256: `7ceb6babd484d5dc22f74b2822c76c0898feffc383d4f309d00274875f902891`.

## Installation

Install with Mod Organizer 2 or copy the files into the Fallout 4 `Data` directory while preserving this structure:

```text
F4SE/
└── Plugins/
    ├── WashThatBody.dll
    └── WashThatBody.ini
```

The mod does not contain an ESP/ESL plugin and therefore does not use a load-order slot.

## Usage

Press **P** during normal gameplay to clean blood from the player character.

The default configuration is stored in `Data/F4SE/Plugins/WashThatBody.ini`:

```ini
[Hotkey]
KeyCode=80
```

If the INI is missing, the built-in default remains `80` (`P`).

## Validation

Version 0.2.2 was tested with the player simultaneously wearing or displaying:

- multiple body tattoos;
- makeup and running mascara;
- lipstick and eyeshadow;
- several body overlays;
- extensive front and back blood decals.

Only the blood decals were removed. Tattoos, makeup, and overlays remained unchanged. Nearby bloody NPCs were not cleaned, and repeated hotkey presses did not cause a crash.

Example console output:

```text
[WashThatBody] 1 skinned decal node(s), 52 decal(s) expired.
[WashThatBody] Player decal cleanup executed.
```

## Technical Notes

The plugin targets `PlayerCharacter` directly and traverses the player's first-person and third-person scene graphs. Objects named `Skinned Decal Node` are validated through the engine's NiRTTI hierarchy before being treated as `BGSDecalNode` objects. The lifetime of their temporary decal effects is then set to zero.

The RTTI validation is important: a regular `NiNode` can use the same object name as its actual `BGSDecalNode` parent. Version 0.2.1 relied on the name alone and could crash when the hotkey was pressed. Version 0.2.2 fixes that error.

## Compatibility

This binary is built specifically for Fallout 4 OldGen 1.10.163. Do not install it on a Next-Gen runtime unless a compatible build is released.

The mod should be compatible with most blood, texture, body, tattoo, and overlay setups because it does not replace textures or edit game records. Compatibility with every possible mod setup cannot be guaranteed.

## Credits

- **powerofthree** and *Wash That Blood Off* for the original inspiration and for pointing the project toward a standalone F4SE implementation.
- **LucaDotGit** for the OldGen-compatible CommonLibF4 fork used to build the plugin.
- The F4SE and CommonLibF4 contributors.

Wash That Body contains its own independently implemented cleanup routine and does not redistribute Wash That Blood Off or any of its assets.

## Permissions

The repository-wide modding and redistribution permissions apply to this project. Third-party frameworks and components remain subject to their respective licenses.
