LEFT INTERACT VANILLA 0.2.1
===========================

Open-source Vanilla 1.12.1 port for the Microbot client.
Targets Interface 11200 and requires the matching FrameXML patch generated
from the user's own client. No client files or MPQs are included.

FEATURES
--------
- Left click uses trusted LEFTINTERACT_ACTION for native interaction.
- Shift + left keeps native selection and camera control.
- Right click uses trusted LEFTINTERACT_COMBINED for W-compatible movement.
- Held-left steering resumes when right click is released.
- Ground-target spells use native left-click placement.
- Native left click returns while an inventory item is attached.
- Saved settings reapply after account keybindings load.

REQUIRED FRAMEXML PATCH
-----------------------
Microbot blocks protected movement calls from addon Lua. The repository's
scripts/build_framexml_patch.py reads Bindings.xml from your own supported
client and creates Data\patch-Z.MPQ with the two trusted actions.

The patch is not included in the addon ZIP. Follow README.md in the repository
to install pinned dependencies, build the MPQ, and verify its hashes.

BINDING SAFETY
--------------
Vanilla 1.12 has no temporary override-binding API. This port uses SetBinding
for the current session and never calls SaveBindings.

It records BUTTON1, BUTTON2, SHIFT-BUTTON1, and SHIFT-BUTTON2 after account
keybindings load. It restores them when disabled and during logout. Normal
restoration preserves a newer binding change made by another addon.

Emergency recovery:
/leftinteract recover

This force-restores the recorded originals and leaves the addon disabled.
A crash may skip logout, but a full restart reloads the client's saved
bindings because this addon never saves its session changes.

INSTALL
-------
With WoW closed:
1. Build patch-Z.MPQ by following the repository README.
2. Copy patch-Z.MPQ to <Microbot folder>\Data\.
3. Copy LeftInteract to <Microbot folder>\Interface\AddOns\.
4. Restart the client.

COMMANDS
--------
/leftinteract gui
/leftinteract on
/leftinteract off
/leftinteract toggle
/leftinteract status
/leftinteract recover
/leftinteract rightmove on|off
/leftinteract movement combined|independent

MOVEMENT
--------
combined    Trusted W-compatible seamless action. Default.
independent Legacy MOVEFORWARD fallback. It shares movement state with W.

TEST STATUS
-----------
The isolated Microbot client proved trusted loading, seamless held-left
continuity, W independence, ground-target placement, settings persistence,
and clean relog behavior. Automated lifecycle, safety, Lua 5.0.3, patch-source,
and deterministic packaging checks are included in the repository.
