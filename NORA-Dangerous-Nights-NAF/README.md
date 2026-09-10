# NORA Dangerous Nights - NAF

A lightweight Fallout 4 OldGen mod that adds dangerous wake-up encounters built around NAF.

## Description

**NORA Dangerous Nights - NAF** is a standalone wake-up encounter mod inspired by the general idea behind Dangerous Nights, but rebuilt independently for a NAF-based Fallout 4 setup.

It does **not** use the original Dangerous Nights plugin as a master or dependency.

After the player sleeps, the mod checks the current location, performs a configurable probability roll, and may spawn one of four attackers. A short dialogue then offers two possible responses: **Submit** or **Resist**.

Core flow:

```text
Sleep
  -> Wake up
  -> Location classification
  -> Chance roll
  -> Random attacker
  -> Dialogue
      -> Submit
      -> Resist
```

### Submit

The attacker immediately starts an aggressive NAF scene through NAFBridge. The spawned attacker is removed only after the real scene-end event has been received and NAFBridge has completed its restoration work.

### Resist

The encounter becomes a real combat situation.

Possible outcomes:

- **Victory:** the attacker dies and the body is cleaned up shortly afterwards.
- **Escape:** if the attacker gets far enough away, the encounter is abandoned and the attacker is removed.
- **Defeat:** AAF Violate takes over the defeat sequence and NAF scene handling. NORA NDN waits for Violate to finish restoring the actors before cleaning up the attacker.

## Features

- Location-based encounter chances after sleeping.
- Separate configurable chances for player settlements, towns/settlements, dungeons and outdoor/other locations.
- Four custom attackers selected randomly.
- Submit / Resist dialogue flow.
- Direct NAF scene handling through NAFBridge.
- AAF Violate integration for the Resist defeat branch.
- Proper cleanup after NAF scenes, combat death, escape or Violate completion.
- Player movement is locked during the dialogue while camera rotation remains available.
- MCM configuration.
- ESP compacted and ESL-flagged.
- xEdit Check for Errors: 0.

## Hard Requirements

This mod was developed and tested with:

- **Fallout 4 OldGen 1.10.163**
- **F4SE 0.6.23**
- **Mod Configuration Menu (MCM)**
- **NAF**
- **NAFBridge**
- **AAF Violate**

AAF Violate is required because the Resist defeat branch uses its Papyrus script and completion event.

## Soft / Recommended Requirements

### Captive Tattoos / NAF-compatible tattoo systems

NORA NDN does not directly apply tattoos.

If your setup already contains a NAF-compatible tattoo system such as Captive Tattoos, aggressive scenes may trigger tattoos through that external ecosystem. No additional tattoo roll is performed by NORA NDN, avoiding duplicate applications.

## Installation

1. Install the mod with your preferred mod manager.
2. Enable `RHI_NDN.esp`.
3. Make sure all hard requirements are installed and working.
4. Configure the encounter chances in the MCM if desired.
5. **Disable the original Dangerous Nights mod** if it is installed.

The plugin is ESL-flagged and therefore does not consume a normal full plugin slot.

## Updating

When updating NORA NDN, replace the previous version with the new one unless release notes explicitly state otherwise.

Do not compact FormIDs again on an already released plugin.

## Uninstallation

Because NORA NDN uses a running controller quest and sleep events, uninstalling scripted mods mid-game should always be approached carefully.

Recommended procedure:

1. Make sure no NORA NDN encounter or NAF/Violate scene started by the mod is currently active.
2. Disable NORA NDN from its MCM if possible.
3. Create a manual save.
4. Remove the mod.
5. Load the save, wait briefly, then create a new manual save.
6. Keep the pre-uninstall save as a backup.

For the cleanest possible removal, returning to a save made before installing the mod remains the safest option.

## Compatibility & Known Issues

### Dangerous Nights

The original **Dangerous Nights 0.38** must be disabled.

It is not a master or requirement for NORA NDN. Running both mods at the same time would create two independent systems reacting to player sleep and may cause competing wake-up events.

### Sexual Harassment

Sexual Harassment is **not strictly incompatible** with NORA NDN, but it may occasionally interfere if both mods trigger an event at the same time when the player wakes up.

This was observed once during testing. Sexual Harassment is also known to be intrusive with other scene/event-driven mods, so users running complex NAF setups should keep this in mind.

If necessary, temporarily disabling Sexual Harassment using its own hotkey before sleeping is an effective workaround.

### Heavily modded setups

This mod was created and tested in a heavily modded Fallout 4 environment. Because wake-up events, defeat systems and scene managers can overlap, compatibility cannot be guaranteed with every possible combination of mods.

## Languages

The original mod is developed in **English** for Creation Kit and scripting stability.

A separate **French translation** is provided so that the main plugin remains easy to maintain and can also be translated into other languages.

## Developer's Note

This is a personal mod created for my own Fallout 4 setup and shared with the community because others may find it useful.

Bug reports, technical feedback and improvement ideas are welcome, but support is provided on a best-effort basis depending on my available time and interest.

Translations, patches, forks, modifications and improvements are allowed under the repository-wide permissions policy. Proper credit to the original mod is appreciated. Source files are provided whenever possible.

See the main repository README for the full permissions policy.

## Credits

Thanks to the authors and maintainers of:

- NAF
- NAFBridge
- AAF Violate
- Mod Configuration Menu
- the Fallout 4 modding community whose tools and documentation make projects like this possible

The project was inspired by the general concept of Dangerous Nights, but NORA Dangerous Nights - NAF is an independent implementation and does not include or require the original plugin.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md) for release history.

## Release Links

LoversLab release link will be added here once the public file page is online.
