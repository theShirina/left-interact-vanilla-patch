LEFT INTERACT VANILLA 0.2.1
===========================

DOWNLOAD
--------
Get these two files from:
https://github.com/theShirina/left-interact-vanilla-patch/releases/latest

1. LeftInteractVanilla-v0.2.1.zip
2. patch-Z.MPQ

No EXE, Python, or build tool is required.
No client files or MPQs are included in this addon ZIP. The required clean
one-file MPQ is a separate release download.

INSTALL
-------
Close World of Warcraft first.

1. Extract the addon ZIP into <WoW>\Interface\AddOns\.
2. Copy patch-Z.MPQ into <WoW>\Data\.
3. Start the client and open settings with /leftinteract gui.

Expected paths:
<WoW>\Interface\AddOns\LeftInteract\LeftInteract.toc
<WoW>\Data\patch-Z.MPQ

Back up an existing patch-Z.MPQ before replacing it.

FEATURES
--------
- Left click interacts with NPCs and world objects.
- Shift + left keeps native selection and camera control.
- Right click provides W-compatible movement.
- Held-left steering resumes after right click is released.
- Ground-target spells use native left-click placement.
- Native left click returns while an inventory item is attached.

BINDING SAFETY
--------------
The addon uses SetBinding for the current session and never calls SaveBindings.
It restores recorded mouse bindings when disabled and during logout.

Emergency recovery:
/leftinteract recover

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

The separate patch-Z.MPQ contains only:
Interface\FrameXML\Bindings.xml

It contains no executable, login code, account data, GlueXML, or realm changes.
