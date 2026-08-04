#!/usr/bin/env python3
"""Build the tested Left Interact FrameXML patch from a local 1.12 client."""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import mpyq

SOURCE_MEMBER = r"Interface\FrameXML\Bindings.xml"
SOURCE_SHA256 = "c440a1b703676858df3c037b852d40fff0305b1bcf059a23600e93f6df327be2"
PATCHED_SHA256 = "b5b7e3a5ad6ac12d3ef914557f2cc5eb4ca63a0d18d56d064912656debce4b9f"
MPQ_SHA256 = "b6b132871d9107499dbf3f61f2754fd185be710f70798b9b4e47f08d62f224cb"
MPQCLI_VERSION = "0.10.2-4bd21908966bafbafc55c6dd293c68488684d212"
FIXED_MTIME = 315532800  # 1980-01-01 00:00:00 UTC

INSERTION = '''
\t<!-- Left Interact accessibility bindings: trusted FrameXML test only. -->
\t<Binding name="LEFTINTERACT_ACTION" runOnUp="true" hidden="true">
\t\tif ( keystate == "down" ) then
\t\t\tif ( SpellIsTargeting() ) then
\t\t\t\tLeftInteractFrameXML_LeftNative = true;
\t\t\t\tLeftInteractFrameXML_LeftHeld = nil;
\t\t\t\tCameraOrSelectOrMoveStart();
\t\t\telse
\t\t\t\tLeftInteractFrameXML_LeftNative = nil;
\t\t\t\tLeftInteractFrameXML_LeftHeld = true;
\t\t\t\tTurnOrActionStart();
\t\t\tend
\t\telse
\t\t\tif ( LeftInteractFrameXML_LeftNative ) then
\t\t\t\tLeftInteractFrameXML_LeftNative = nil;
\t\t\t\tif ( not LeftInteractFrameXML_RightHeld ) then
\t\t\t\t\tCameraOrSelectOrMoveStop();
\t\t\t\tend
\t\t\telse
\t\t\t\tLeftInteractFrameXML_LeftHeld = nil;
\t\t\t\tif ( not LeftInteractFrameXML_RightHeld ) then
\t\t\t\t\tTurnOrActionStop();
\t\t\t\tend
\t\t\tend
\t\tend
\t</Binding>
\t<Binding name="LEFTINTERACT_COMBINED" runOnUp="true" hidden="true">
\t\tif ( keystate == "down" ) then
\t\t\tLeftInteractFrameXML_RightHeld = true;
\t\t\tCameraOrSelectOrMoveStart();
\t\t\tTurnOrActionStart();
\t\telse
\t\t\tLeftInteractFrameXML_RightHeld = nil;
\t\t\tCameraOrSelectOrMoveStop();
\t\t\tif ( LeftInteractFrameXML_LeftHeld ) then
\t\t\t\tTurnOrActionStart();
\t\t\telse
\t\t\t\tTurnOrActionStop();
\t\t\tend
\t\tend
\t</Binding>
'''


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def patched_bindings(source: bytes) -> bytes:
    actual = sha256(source)
    if actual != SOURCE_SHA256:
        raise RuntimeError(
            "Unsupported source Bindings.xml: "
            f"expected {SOURCE_SHA256}, got {actual}. No file was written."
        )

    text = source.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
    if "LEFTINTERACT_ACTION" in text or "LEFTINTERACT_COMBINED" in text:
        raise RuntimeError("Source already contains Left Interact bindings")
    if text.count("</Bindings>") != 1:
        raise RuntimeError("Expected one closing </Bindings> tag")

    patched = text.replace("</Bindings>", INSERTION + "</Bindings>")
    payload = patched.replace("\n", "\r\n").encode("utf-8")
    actual_patched = sha256(payload)
    if actual_patched != PATCHED_SHA256:
        raise RuntimeError(
            f"Patched payload mismatch: expected {PATCHED_SHA256}, got {actual_patched}"
        )
    return payload


def run_mpqcli(mpqcli: Path, staging: Path, output: Path) -> None:
    flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    version = subprocess.run(
        [str(mpqcli), "version"],
        check=True,
        capture_output=True,
        text=True,
        creationflags=flags,
    ).stdout.strip()
    if version != MPQCLI_VERSION:
        raise RuntimeError(f"Expected mpqcli {MPQCLI_VERSION}, got {version}")

    result = subprocess.run(
        [str(mpqcli), "create", str(staging), "--game", "wow-vanilla", "--output", str(output)],
        capture_output=True,
        text=True,
        creationflags=flags,
    )
    if result.returncode:
        detail = (result.stderr or result.stdout).strip()
        raise RuntimeError(f"mpqcli failed ({result.returncode}): {detail}")


def verify_archive(path: Path, payload: bytes) -> None:
    actual_mpq = sha256(path.read_bytes())
    if actual_mpq != MPQ_SHA256:
        raise RuntimeError(f"MPQ mismatch: expected {MPQ_SHA256}, got {actual_mpq}")

    archive = mpyq.MPQArchive(str(path))
    names = {item.decode() if isinstance(item, bytes) else str(item) for item in archive.files}
    if names != {SOURCE_MEMBER}:
        raise RuntimeError(f"Unexpected MPQ members: {sorted(names)}")
    if archive.read_file(SOURCE_MEMBER) != payload:
        raise RuntimeError("MPQ payload readback differs from staged Bindings.xml")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build Left Interact patch-Z.MPQ from a supported local Microbot 1.12.1 client."
    )
    parser.add_argument("--client-data", required=True, type=Path, help="Path to the client's Data folder")
    parser.add_argument("--mpqcli", required=True, type=Path, help="Path to mpqcli 0.10.2")
    parser.add_argument("--output", required=True, type=Path, help="Destination patch-Z.MPQ")
    args = parser.parse_args()

    source_archive = args.client_data / "patch.MPQ"
    if not source_archive.is_file():
        raise RuntimeError(f"Missing source archive: {source_archive}")
    if not args.mpqcli.is_file():
        raise RuntimeError(f"Missing mpqcli: {args.mpqcli}")

    source = mpyq.MPQArchive(str(source_archive), listfile=False).read_file(SOURCE_MEMBER)
    if not source:
        raise RuntimeError(f"Missing {SOURCE_MEMBER} in {source_archive}")
    payload = patched_bindings(source)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="left-interact-patch-") as temporary_dir:
        temporary = Path(temporary_dir)
        staging = temporary / "patch-root"
        staged_payload = staging / "Interface" / "FrameXML" / "Bindings.xml"
        staged_payload.parent.mkdir(parents=True)
        staged_payload.write_bytes(payload)
        for path in (staged_payload, staged_payload.parent, staged_payload.parent.parent, staging):
            os.utime(path, (FIXED_MTIME, FIXED_MTIME))
        built = temporary / "patch-Z.MPQ"
        run_mpqcli(args.mpqcli.resolve(), staging.resolve(), built.resolve())
        verify_archive(built, payload)

        destination_temp = args.output.with_name(f".{args.output.name}.tmp")
        destination_temp.unlink(missing_ok=True)
        shutil.copy2(built, destination_temp)
        verify_archive(destination_temp, payload)
        os.replace(destination_temp, args.output)

    print(f"Built: {args.output}")
    print(f"Bindings.xml SHA-256: {PATCHED_SHA256}")
    print(f"patch-Z.MPQ SHA-256: {MPQ_SHA256}")


if __name__ == "__main__":
    main()
