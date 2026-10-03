# NORA Dangerous Nights - NAF

A lightweight Fallout 4 OldGen wake-up encounter mod built around NAF.

## Status

**Version 1.1.0 — prepared for publication**  
The project page is available on [LoversLab](https://www.loverslab.com/files/file/51420-nora-dangerous-nights-naf/).

## Description

**NORA Dangerous Nights - NAF** is a standalone wake-up encounter mod inspired by the general concept of Dangerous Nights and rebuilt independently for a NAF-based Fallout 4 setup.

It does **not** use the original Dangerous Nights plugin as a master or dependency.

After the player sleeps, NORA NDN can either:

- start its own configurable encounter with one to three randomly selected attackers; or
- optionally hand the wake-up event over to **Pervert – Immersive Prostitution and Harassment**.

Core flow:

```text
Sleep -> Wake up -> Optional Pervert roll
                    | accepted -> Pervert handles the event
                    | otherwise -> Location chance roll
                                   -> 1–3 attackers
                                   -> Submit or Resist
```

## Main Features

- Location-based encounter chances for player settlements, NPC settlements, dungeons and outdoor/other locations.
- One to three attackers, with the maximum configurable in the MCM.
- Four custom attacker ActorBases selected without duplicates for each encounter.
- Automatic approach, safety repositioning and dialogue-camera handling.
- Submit / Resist dialogue flow.
- Multi-actor NAF scene requests through NAFBridge.
- AAF Violate integration for defeat after resistance.
- Engine-safe delayed cleanup designed to avoid cold-load save crashes after NAF scenes.
- Optional Pervert v0.4.1+ hand-off with configurable probability and narrative messages.
- Debug notifications can be enabled or disabled in the MCM.
- Fast JSON-based MCM powered by the F4SE MCM framework.
- ESL-flagged ESP; xEdit **Check for Errors: 0**.

### Submit

All available encounter actors are sent to NAFBridge. NORA NDN waits for the real scene-end event, gives NAFBridge time to restore actors, releases the group, and only then begins deferred engine-safe deletion.

Users need compatible animation packs that include animations for the desired number of participants. **NORA Dangerous Nights does not include animations.** If no compatible multi-participant animation is installed, NAF may be unable to start a scene with two or three attackers.

### Resist

The encounter becomes a real combat situation involving the whole group.

- **Victory:** dead attackers are cleaned up safely.
- **Escape:** the encounter ends once the remaining attackers are far enough away.
- **Defeat:** AAF Violate takes over. NORA NDN waits for Violate's completion event before cleanup.

### Optional Pervert Integration

The **Pervert abduction chance** is disabled by default (`0%`). When enabled and the roll succeeds, NORA NDN calls Pervert's API before evaluating its normal location chances.

Pervert then owns the abduction, dungeon selection, actors, scenes, return transport and cleanup. NORA NDN does not spawn attackers for that branch.

This integration:

- requires **Pervert – Immersive Prostitution and Harassment v0.4.1 or later**;
- dynamically detects `pervert.esp` and calls its API;
- does not add Pervert as a plugin master;
- contains no Pervert assets, scripts or data;
- falls back to the normal NORA NDN evaluation if Pervert is missing, unavailable or rejects the request.

The three narrative messages are stored in `Data\F4SE\Plugins\RHI_NDN_messages.ini`, making them easy to translate without recompiling the scripts.

## Requirements

### Hard Requirements

- **Fallout 4 OldGen 1.10.163**
- **F4SE 0.6.23**
- **Mod Configuration Menu / F4SE MCM framework**
- **NAF**
- **NAFBridge**
- **AAF Violate**

AAF Violate is required because the Resist defeat branch uses its Papyrus script and completion event.

### Optional Requirements

- **Pervert – Immersive Prostitution and Harassment v0.4.1+** — only required when the Pervert probability is set above 0%.
- NAF-compatible tattoo systems such as Captive Tattoos. NORA NDN does not apply tattoos directly.
- Compatible NAF animation packs, including multi-participant animations when using more than one attacker.

## Installation

1. Install the mod with your preferred mod manager.
2. Enable `RHI_NDN.esp`.
3. Make sure the hard requirements are installed and working.
4. Configure encounter chances and the maximum attacker count in the MCM.
5. Leave the Pervert chance at `0%` unless Pervert v0.4.1+ is installed and you want that integration.
6. Disable the original Dangerous Nights mod if it is installed.

The plugin is ESL-flagged and does not consume a normal full plugin slot.

## Updating

Replace the previous version with the new one unless the release notes explicitly state otherwise. Do not compact the released plugin's FormIDs again.

Version 1.1.0 adds new persistent settings and substantial controller changes. Keep a backup save before updating any scripted mod.

## Uninstallation

1. Make sure no NORA NDN, NAF, Violate or Pervert event started by the mod is active.
2. Disable NORA NDN in its MCM.
3. Create a manual backup save.
4. Remove the mod.
5. Load the save, wait briefly, and create a new manual save.

Returning to a save made before installing the mod remains the safest removal method.

## Compatibility and Notes

### Original Dangerous Nights

The original **Dangerous Nights 0.38** must be disabled. Running both systems can create competing wake-up events.

### Sexual Harassment and other wake-up systems

Sexual Harassment is not strictly incompatible, but simultaneous wake-up events can interfere with one another. In very complex setups, temporarily disabling other event systems before sleeping can help isolate conflicts.

### AAF-only environments

Users have reported that the earlier stable release works correctly in AAF-only environments. Version 1.1.0 was developed and stress-tested primarily with NAF/NAFBridge, including cold loading saves created after Submit and Resist encounters.

### Heavily modded setups

Wake-up handlers, defeat systems, camera controllers and scene managers can overlap. Compatibility with every possible mod combination cannot be guaranteed.

## Languages

The original mod is developed in English for Creation Kit and scripting stability. A separate French translation is maintained for distribution.

## Credits

Thanks to the authors and maintainers of:

- NAF
- NAFBridge
- AAF Violate
- Mod Configuration Menu and the F4SE MCM framework
- the Fallout 4 modding community

Special thanks to **[riveth](https://www.loverslab.com/profile/8946296-riveth/)** for **Pervert – Immersive Prostitution and Harassment v0.4.1** and its public API/source. NORA NDN only performs a dynamic API hand-off; it includes no Pervert content and does not use Pervert as a master.

The project was inspired by the general concept of Dangerous Nights, but NORA Dangerous Nights - NAF is an independent implementation and does not include or require the original plugin.

## Developer's Note

This is a personal mod shared with the community because others may find it useful. Bug reports, technical feedback and improvement ideas are welcome, with support provided on a best-effort basis.

Translations, patches, forks, modifications and improvements are allowed under the repository-wide permissions policy. Proper credit is appreciated. Public source files are provided whenever possible.

## Changelog and Release

- [Changelog](CHANGELOG.md)
- [LoversLab release page](https://www.loverslab.com/files/file/51420-nora-dangerous-nights-naf/)
