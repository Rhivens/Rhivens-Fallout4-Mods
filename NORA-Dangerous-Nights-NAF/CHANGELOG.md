# Changelog — NORA Dangerous Nights - NAF

## Version 0.18 RC1 — 3 October 2026

### Added

- Configurable random encounters with one to three attackers.
- Maximum attacker count slider in the MCM.
- Optional Pervert v0.4.1+ integration with a configurable probability, disabled by default.
- Dynamic call to Pervert's `startCustomAbduction` API without adding `pervert.esp` as a master.
- External narrative messages in `RHI_NDN_messages.ini` with built-in English fallbacks.
- MCM debug toggle.
- Fast JSON-based MCM configuration through the F4SE MCM framework.

### Improved

- Attacker approach, emergency repositioning and player/dialogue orientation.
- Dialogue camera ownership and cleanup.
- Multi-actor Submit and Resist handling.
- Individual death tracking and group cleanup.
- English debug and diagnostic messages.

### Stability

- Reworked Submit cleanup to respect NAFBridge's actor-restoration window.
- Added delayed retirement and two clean verification passes before `DeleteWhenAble`.
- Rearmed deferred deletion safely after loading a save.
- Avoided deleting temporary actors while their cell or NAF scene association is still active.
- Validated repeated cold loading after single and multiple Submit/Resist encounters.
- Corrected the new GlobalVariable FormIDs for the ESL-flagged plugin.
- xEdit check completed with 58 processed records and 0 errors.

### Notes

- NORA NDN does not include animations. Multi-attacker scenes require compatible multi-participant NAF animation packs.
- Pervert handles its own actors, transport, scenes and cleanup when the optional hand-off succeeds.

## Initial public release

- Standalone wake-up encounter system.
- Location-based probability handling.
- Random attacker selection.
- Submit / Resist dialogue flow.
- NAF scene launch through NAFBridge.
- AAF Violate integration for defeat after resistance.
- Cleanup handling after scenes, death or escape.
- MCM configuration.
- Fallout 4 OldGen 1.10.163 support.
