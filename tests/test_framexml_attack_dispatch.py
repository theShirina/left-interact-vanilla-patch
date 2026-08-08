#!/usr/bin/env python3
"""Execute the trusted hostile-NPC click branch against mocked Vanilla APIs."""

from __future__ import annotations

import argparse
import importlib.util
import os
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "scripts" / "build_framexml_patch.py"


def load_insertion() -> str:
    spec = importlib.util.spec_from_file_location("build_framexml_patch", BUILDER)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(module)
    return module.INSERTION


def binding_script(name: str) -> str:
    insertion = load_insertion()
    if "LeftInteractDB" in insertion:
        raise AssertionError("trusted FrameXML must not read addon-owned LeftInteractDB data")
    if "LeftInteractFrameXML_LootClickTime" in insertion:
        raise AssertionError("trusted FrameXML must not bridge auto-loot state into addon Lua")
    match = re.search(
        rf'<Binding name="{re.escape(name)}"[^>]*>(.*?)</Binding>',
        insertion,
        re.DOTALL,
    )
    if not match:
        raise RuntimeError(f"{name} missing from patch insertion")
    return match.group(1)


def harness() -> str:
    action = binding_script("LEFTINTERACT_ACTION")
    no_attack = binding_script("LEFTINTERACT_NO_ATTACK")
    return f'''
local cameraCalls = 0
local actionCalls = 0
local hostile = true
local playerUnit = false
local deadUnit = false
local spellTargeting = false

function SpellIsTargeting() return spellTargeting end
function UnitExists(unit) return unit == "mouseover" end
function UnitCanAttack(source, target) return hostile and source == "player" and target == "mouseover" end
function UnitIsPlayer(unit) return playerUnit end
function UnitIsDead(unit) return deadUnit end
function CameraOrSelectOrMoveStart() cameraCalls = cameraCalls + 1 end
function CameraOrSelectOrMoveStop() end
function TurnOrActionStart() actionCalls = actionCalls + 1 end
function TurnOrActionStop() end

local function RunStandardAction()
{action}
end

local function RunNoAttackAction()
{no_attack}
end

local function Dispatch(binding, isPlayer, isDead, isSpell, expectedCamera, expectedAction, name)
    cameraCalls = 0
    actionCalls = 0
    playerUnit = isPlayer
    deadUnit = isDead
    spellTargeting = isSpell
    keystate = "down"
    if binding == "standard" then
        RunStandardAction()
    else
        RunNoAttackAction()
    end
    assert(cameraCalls == expectedCamera, name .. ": wrong native-selection call count")
    assert(actionCalls == expectedAction, name .. ": wrong interaction/attack call count")
end

Dispatch("standard", false, false, false, 0, 1, "standard living hostile NPC")
Dispatch("standard", true, false, false, 0, 1, "standard hostile player")
Dispatch("standard", false, true, false, 0, 1, "standard dead hostile NPC")
Dispatch("standard", false, false, true, 1, 0, "standard ground-target spell")
Dispatch("no-attack", false, false, false, 1, 0, "no-attack living hostile NPC")
Dispatch("no-attack", true, false, false, 0, 1, "no-attack hostile player")
Dispatch("no-attack", false, true, false, 0, 1, "no-attack dead hostile NPC")
Dispatch("no-attack", false, false, true, 1, 0, "no-attack ground-target spell")
print("FrameXML hostile-NPC dispatch: PASS")
'''


def run_external(lua: Path, script: str) -> None:
    flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    with tempfile.NamedTemporaryFile("w", suffix=".lua", encoding="utf-8", delete=False) as handle:
        handle.write(script)
        temporary = Path(handle.name)
    try:
        subprocess.run([str(lua), str(temporary)], check=True, creationflags=flags)
    finally:
        temporary.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--lua", type=Path, help="Lua 5.0.3 executable")
    group.add_argument("--lupa", action="store_true", help="Use local Lupa for development")
    args = parser.parse_args()
    script = harness()

    if args.lupa:
        from lupa import LuaRuntime

        LuaRuntime(unpack_returned_tuples=True).execute(script)
    else:
        if not args.lua.is_file():
            raise RuntimeError(f"Lua executable not found: {args.lua}")
        run_external(args.lua.resolve(), script)


if __name__ == "__main__":
    main()
