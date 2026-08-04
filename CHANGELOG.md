# Changelog

## [0.2.1] - 2026-08-04

- Use trusted FrameXML actions for seamless held-left steering and W-compatible right-click movement.
- Preserve native left-click placement for ground-target spells.
- Reapply saved settings after account keybindings finish loading.
- Keep protected movement calls outside addon Lua and never call `SaveBindings`.
- Add a source-only builder that creates and verifies the required MPQ from the user's own supported client.

## [0.1.0] - 2026-08-04

- Port Left Interact to Vanilla 1.12.1 and Interface 11200.
- Replace later-client override bindings with reversible session-only `SetBinding` changes.
- Preserve newer mouse-binding changes made by another addon during normal disable or logout.
- Preserve original bindings across `/reload` and add `/leftinteract recover`.
- Support trusted combined movement and the stock `MOVEFORWARD` fallback.
- Restore native BUTTON1 while an inventory item is attached to the cursor.
- Keep the settings and What's New pages.
