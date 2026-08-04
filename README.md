# Left Interact Vanilla + FrameXML Patch

Left-click interaction and seamless mouse steering for the Microbot World of Warcraft 1.12.1 client.

This repository contains the Interface 11200 addon and a source-only builder for its required trusted FrameXML patch. It does **not** contain a game executable, client MPQ, extracted Blizzard FrameXML, account data, or login/realm modifications.

## Features

- Left click interacts with NPCs, corpses, gathering nodes, and world objects.
- Shift + left click keeps native selection and camera control.
- Right click provides W-compatible movement while left remains held.
- Releasing right click resumes held-left steering.
- Ground-target spells use native left-click placement.
- Native left click returns while an inventory item is attached.
- `/leftinteract recover` restores the recorded mouse bindings.

## Why a FrameXML patch is required

Microbot blocks protected movement calls from addon Lua. The addon therefore maps mouse buttons to two trusted actions defined in the client's effective `Interface\FrameXML\Bindings.xml`.

The builder reads that file from your own client, adds only the two Left Interact actions, creates `patch-Z.MPQ`, and reads the result back before accepting it. It rejects unknown source files and unsupported `mpqcli` versions.

## Requirements

- Microbot WoW 1.12.1 with the supported `Data\patch.MPQ`.
- Python 3.11 or later.
- [`mpqcli` 0.10.2](https://github.com/TheGrayDot/mpqcli/releases), exact build `0.10.2-4bd21908966bafbafc55c6dd293c68488684d212`.

## Build the patch

Install the pinned Python dependency:

```bash
python -m pip install --require-hashes -r requirements-patch.txt
```

Run the builder while WoW is closed:

```bash
python scripts/build_framexml_patch.py \
  --client-data "C:/Games/Microbot/Data" \
  --mpqcli "C:/Tools/mpqcli.exe" \
  --output "dist/patch-Z.MPQ"
```

Verified hashes:

```text
Stock Bindings.xml:   c440a1b703676858df3c037b852d40fff0305b1bcf059a23600e93f6df327be2
Patched Bindings.xml: b5b7e3a5ad6ac12d3ef914557f2cc5eb4ca63a0d18d56d064912656debce4b9f
Built patch-Z.MPQ:    b6b132871d9107499dbf3f61f2754fd185be710f70798b9b4e47f08d62f224cb
```

## Install

Build the addon ZIP:

```bash
python -m pip install --require-hashes -r requirements-dev.txt
python scripts/validate.py
python scripts/build_release.py
```

With WoW closed:

1. Extract `LeftInteract` into `<WoW>\Interface\AddOns\`.
2. Copy the generated `patch-Z.MPQ` into `<WoW>\Data\`.
3. Start the client and open settings with `/leftinteract gui`.

Back up an existing `patch-Z.MPQ` before replacing it. To roll back, close WoW, restore the prior MPQ, and restore or remove the addon folder.

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
```

The addon uses session-only `SetBinding` changes and never calls `SaveBindings`.

## Scope

This project targets Microbot WoW 1.12.1 and Interface 11200. The patch builder adds no GlueXML, login, account, or realm-selection code. Other Vanilla clients may ship a different `Bindings.xml`; the builder will reject them rather than guess.

The addon and builder are licensed under MIT. World of Warcraft and Blizzard FrameXML are owned by Blizzard Entertainment; no Blizzard files are distributed here.
