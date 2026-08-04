#!/usr/bin/env python3
"""Validate the public Vanilla 1.12 addon and source-only patch builder."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from luaparser import ast

ROOT = Path(__file__).resolve().parents[1]
TOC = ROOT / "LeftInteract.toc"
LUA = ROOT / "LeftInteract.lua"
README = ROOT / "README.md"
PACKAGE_README = ROOT / "README.txt"
CHANGELOG = ROOT / "CHANGELOG.md"
ADDON_BUILDER = ROOT / "scripts" / "build_release.py"
PATCH_BUILDER = ROOT / "scripts" / "build_framexml_patch.py"
PATCH_LOCK = ROOT / "requirements-patch.txt"
WORKFLOW = ROOT / ".github" / "workflows" / "validate.yml"

ALLOWED_TOP_LEVEL = {
    ".gitattributes",
    ".github",
    ".gitignore",
    "CHANGELOG.md",
    "CONTRIBUTING.md",
    "LICENSE",
    "LeftInteract.lua",
    "LeftInteract.toc",
    "README.md",
    "README.txt",
    "requirements-dev.txt",
    "requirements-patch.in",
    "requirements-patch.txt",
    "scripts",
    "tests",
}
FORBIDDEN_SUFFIXES = {
    ".7z", ".blp", ".dll", ".exe", ".gif", ".jpeg", ".jpg", ".mp3",
    ".mpq", ".ogg", ".png", ".rar", ".tga", ".wav", ".webp", ".zip",
}
FORBIDDEN_PATCH_TOKENS = (
    "GlueParent",
    "RealmList",
    "Microbot Vanilla",
    "OPEN_STATUS_DIALOG",
    "RESPONSE_SUCCESS",
    "SetPreferredInfo",
    "ChangeRealm",
)


class ValidationError(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def toc_value(text: str, key: str) -> str:
    match = re.search(rf"^## {re.escape(key)}:\s*(.+?)\s*$", text, re.MULTILINE)
    if not match:
        raise ValidationError(f"Missing TOC field: {key}")
    return match.group(1)


def public_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts or path.name.startswith(".coverage"):
            continue
        if any(part in {"dist", "dist-a", "dist-b", "__pycache__"} for part in path.parts):
            continue
        files.append(path)
    return sorted(files)


def validate_public_boundary(files: list[Path]) -> None:
    actual_top = {path.relative_to(ROOT).parts[0] for path in files}
    unexpected = sorted(actual_top - ALLOWED_TOP_LEVEL)
    require(not unexpected, f"Unexpected top-level public content: {unexpected}")

    private_patterns = (
        re.compile(r"(?i)[A-Z]:[/\\]Users[/\\]"),
        re.compile(r"(?i)E:[/\\]Hermes"),
        re.compile("(?i)" + "Not" + "andi"),
        re.compile(r"gh[pousr]_[A-Za-z0-9_]{20,}"),
        re.compile(r"https://(?:canary\.|ptb\.)?discord(?:app)?\.com/api/webhooks/"),
        re.compile(r"(?i)(password|passwd|api[_-]?key|secret|webhook)[ \t]*[:=][ \t]*[^\s#]{6,}"),
    )

    for path in files:
        relative = path.relative_to(ROOT).as_posix()
        require(path.suffix.lower() not in FORBIDDEN_SUFFIXES, f"Forbidden public binary/archive: {relative}")
        data = path.read_bytes()
        require(b"\x00" not in data, f"Unexpected binary file: {relative}")
        text = data.decode("utf-8")
        for pattern in private_patterns:
            require(not pattern.search(text), f"Private or secret-bearing pattern in {relative}")


def main() -> int:
    files = public_files()
    validate_public_boundary(files)

    toc = TOC.read_text(encoding="utf-8")
    lua = LUA.read_text(encoding="utf-8")
    readme = README.read_text(encoding="utf-8")
    package_readme = PACKAGE_README.read_text(encoding="utf-8")
    changelog = CHANGELOG.read_text(encoding="utf-8")
    addon_builder = ADDON_BUILDER.read_text(encoding="utf-8")
    patch_builder = PATCH_BUILDER.read_text(encoding="utf-8")
    patch_lock = PATCH_LOCK.read_text(encoding="utf-8")
    workflow = WORKFLOW.read_text(encoding="utf-8")

    interface = toc_value(toc, "Interface")
    version = toc_value(toc, "Version")
    require(interface == "11200", f"Expected Interface 11200, got {interface}")
    require(version == "0.2.1", f"Expected version 0.2.1, got {version}")
    require("Private" not in toc, "TOC still marks the addon private")
    require(package_readme.startswith(f"LEFT INTERACT VANILLA {version}\n"), "README.txt version differs from TOC")
    require(f'local ADDON_VERSION = "{version}"' in lua, "GUI source version differs from TOC")

    toc_files = [line.strip() for line in toc.splitlines() if line.strip() and not line.lstrip().startswith("#")]
    require(toc_files == ["LeftInteract.lua"], f"Unexpected TOC file list: {toc_files}")
    for name in toc_files:
        require((ROOT / name).is_file(), f"TOC references missing file: {name}")

    try:
        ast.parse(lua)
    except Exception as exc:
        raise ValidationError(f"Lua syntax error: {exc}") from exc

    required_addon_tokens = (
        "GetBindingAction",
        "SetBinding",
        "originalBindings",
        "originalsCaptured",
        'controller:RegisterEvent("PLAYER_LOGOUT")',
        'controller:RegisterEvent("PLAYER_LOGIN")',
        'SetTrackedBinding("BUTTON1", leftAction)',
        'SetTrackedBinding("BUTTON2", movementAction)',
        'local leftAction = "LEFTINTERACT_ACTION"',
        'LeftInteractDB.movementMode == "combined" and "LEFTINTERACT_COMBINED" or "MOVEFORWARD"',
        'SetTrackedBinding("SHIFT-BUTTON1", "CAMERAORSELECTORMOVE")',
        'SetTrackedBinding("SHIFT-BUTTON2", "TURNORACTION")',
        'command == "recover"',
    )
    for token in required_addon_tokens:
        require(token in lua, f"Required Vanilla behavior missing: {token}")

    require(not re.search(r"\bSaveBindings\s*\(", lua), "Addon must never call SaveBindings")
    for protected_call in (
        "TurnOrActionStart", "TurnOrActionStop", "CameraOrSelectOrMoveStart",
        "CameraOrSelectOrMoveStop", "MoveForwardStart", "MoveForwardStop",
    ):
        require(protected_call not in lua, f"Protected FrameXML call leaked into addon Lua: {protected_call}")
    require("SetOverrideBinding" not in lua and "ClearOverrideBindings" not in lua, "Later-client override API leaked into Vanilla addon")
    require("function(self" not in lua and "function (self" not in lua, "Modern self callback remains")

    required_patch_tokens = (
        'SOURCE_MEMBER = r"Interface\\FrameXML\\Bindings.xml"',
        'SOURCE_SHA256 = "c440a1b703676858df3c037b852d40fff0305b1bcf059a23600e93f6df327be2"',
        'PATCHED_SHA256 = "b5b7e3a5ad6ac12d3ef914557f2cc5eb4ca63a0d18d56d064912656debce4b9f"',
        'MPQ_SHA256 = "b6b132871d9107499dbf3f61f2754fd185be710f70798b9b4e47f08d62f224cb"',
        'MPQCLI_VERSION = "0.10.2-4bd21908966bafbafc55c6dd293c68488684d212"',
        "FIXED_MTIME = 315532800",
        '<Binding name="LEFTINTERACT_ACTION" runOnUp="true" hidden="true">',
        '<Binding name="LEFTINTERACT_COMBINED" runOnUp="true" hidden="true">',
        "SpellIsTargeting()",
        "verify_archive(destination_temp, payload)",
        "os.replace(destination_temp, args.output)",
        "subprocess.CREATE_NO_WINDOW",
        "os.utime(path, (FIXED_MTIME, FIXED_MTIME))",
    )
    for token in required_patch_tokens:
        require(token in patch_builder, f"Patch builder guard missing: {token}")
    for token in FORBIDDEN_PATCH_TOKENS:
        require(token not in patch_builder, f"Unrelated Glue/login/realm code in patch builder: {token}")

    require("mpyq==0.2.5" in patch_lock, "mpyq is not pinned to 0.2.5")
    require("sha256:30aaf5962be569f3f2b53978060cd047434ee4f5a215925dd6ff0fef04ec0007" in patch_lock, "mpyq hash missing")
    require("E:/" not in patch_lock and "C:/" not in patch_lock, "Absolute path leaked into patch lockfile")

    require("info.create_system = 3" in addon_builder, "ZIP platform metadata is not fixed")
    require("zipfile.ZIP_STORED" in addon_builder, "ZIP compression is not deterministic")
    require('text.replace("\\r\\n", "\\n").replace("\\r", "\\n")' in addon_builder, "ZIP builder does not canonicalize LF")

    require("No client files or MPQs are included" in package_readme, "Package README lacks client-file boundary")
    require("releases/latest/download/LeftInteractVanilla-v0.2.1.zip" in readme, "Direct addon download missing")
    require("releases/latest/download/patch-Z.MPQ" in readme, "Direct patch download missing")
    require("You do not need to download an EXE, Python, or any build tool" in readme, "Simple no-EXE install promise missing")
    require("does **not** contain a game executable" in readme, "Public README lacks source boundary")
    require("no executable, login code, account data, GlueXML, or realm-selection changes" in readme, "README lacks patch boundary")
    require("never calls `SaveBindings`" in readme, "README lacks binding safety statement")
    require("/leftinteract recover" in readme and "/leftinteract recover" in package_readme, "Recovery command missing")
    require(re.search(r"^## \[0\.2\.1\] - 2026-08-04$", changelog, re.MULTILINE) is not None, "Current changelog entry missing")

    action_refs = re.findall(r"uses:\s*[^@\s]+@([0-9a-f]{40})", workflow)
    require(len(action_refs) == 3, f"Expected three SHA-pinned workflow actions, got {len(action_refs)}")
    require("permissions:\n  contents: read" in workflow, "Workflow permissions are not read-only")
    require("requirements-patch.txt" in workflow and "build_framexml_patch.py --help" in workflow, "CI does not check patch tooling")

    print(f"Validated Left Interact Vanilla {version} (Interface {interface})")
    print(f"Public source boundary: PASS ({len(files)} files)")
    print("Lua syntax and Vanilla binding guards: PASS")
    print("Source-only FrameXML patch guards: PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValidationError, OSError, SyntaxError, UnicodeDecodeError) as exc:
        print(f"Validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
