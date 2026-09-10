# NORA Dangerous Nights - NAF

A lightweight Fallout 4 OldGen mod that adds dangerous wake-up encounters built around NAF.

## Status

Public release preparation in progress.

## Overview

NORA Dangerous Nights - NAF is inspired by the basic idea of Dangerous Nights, but it is a standalone implementation and does not use Dangerous Nights as a master.

Core flow:

```text
Sleep -> Wake up -> Location check -> Chance roll -> Attacker encounter
```

The encounter then branches into dialogue choices such as submission or resistance, with NAF used for aggressive scenes and AAF Violate handling the defeat branch when resistance fails.

## Supported environment

- Fallout 4 OldGen 1.10.163
- F4SE 0.6.23
- Mod Configuration Menu (MCM)
- NAF
- NAFBridge
- AAF Violate

## Compatibility notes

- Dangerous Nights 0.38 should be disabled to avoid two competing sleep-event systems.
- Sexual Harassment may occasionally interfere if it triggers an event at the same time as NORA NDN when the player wakes up.

## Languages

The mod is developed in English for Creation Kit / scripting stability.

A separate French translation is planned/provided for release.

## Documentation

Detailed technical documentation, implementation notes and development history are kept separately in the private development repository.

## Release links

LoversLab release link will be added here once published.
