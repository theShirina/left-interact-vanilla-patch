# Left Interact Vanilla

Left-click interaction and seamless mouse steering for the WoW 1.12 client.

## Downloads

Download these two files from the latest release:

1. **[LeftInteractVanilla-v0.3.0.zip](https://github.com/theShirina/left-interact-vanilla-patch/releases/latest/download/LeftInteractVanilla-v0.3.0.zip)** — addon
2. **[patch-Z.MPQ](https://github.com/theShirina/left-interact-vanilla-patch/releases/latest/download/patch-Z.MPQ)** — required FrameXML patch

You do not need to download an EXE, Python, or any build tool.

## Install

Close World of Warcraft first.

1. Extract the addon ZIP into `<WoW>\Interface\AddOns\`.
2. Copy `patch-Z.MPQ` into `<WoW>\Data\`.
3. Start the client and open settings with `/leftinteract gui`.

The final paths should be:

```text
<WoW>\Interface\AddOns\LeftInteract\LeftInteract.toc
<WoW>\Data\patch-Z.MPQ
```

Back up an existing `patch-Z.MPQ` before replacing it.

## Features

- Left click interacts with NPCs, corpses, gathering nodes, and world objects.
- Shift + left click keeps native selection and camera control.
- Right click provides W-compatible movement while left remains held.
- Releasing right click resumes held-left steering.
- Ground-target spells use native left-click placement.
- Native left click returns while an inventory item is attached.
- Short empty-world clicks clear the current target by default.
- Choose whether left click starts attacking living hostile creatures or only selects them.
- The hostile-creature setting switches between separate trusted actions; FrameXML never reads addon settings.
- `/leftinteract recover` restores the recorded mouse bindings.

## Commands

```text
/leftinteract gui
/leftinteract on
/leftinteract off
/leftinteract toggle
/leftinteract status
/leftinteract recover
/leftinteract rightmove on|off
/leftinteract movement combined|independent
/leftinteract attack on|off
```

The addon uses session-only `SetBinding` changes and never calls `SaveBindings`.

The patch contains one file:

```text
Interface\FrameXML\Bindings.xml
```

It contains no executable, login code, account data, GlueXML, or realm-selection changes.

## Open source

The addon, tests, validator, release packager, and patch-builder source are in this repository under the MIT license. The patch builder exists for audit and maintenance; release users do not need it.

This repository does **not** contain a game executable, account data, logs, or client data. The released MPQ contains the one client-compatible binding override required by Left Interact.

This project targets WoW 1.12 and Interface 11200. World of Warcraft and Blizzard FrameXML are owned by Blizzard Entertainment.
