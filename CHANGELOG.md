# Changelog

## 0.3.0 — 2026-08-08

### Added

- Choose whether left click starts an attack on living hostile creatures or only selects them.
- Use `/leftinteract attack on|off` to change that setting.

### Changed

- Short empty-world clicks clear the current target by default, with one-time migration for existing 0.2.1 settings.
- Corpses, hostile players, gathering nodes, and world objects keep their normal interaction behavior.
- The settings panel is more compact; `/leftinteract recover` remains available.

## 0.2.1 — 2026-08-04

### Added

- Use held-left steering with W-compatible right-click movement.
- Keep native left-click placement for ground-target spells.
- Reapply saved settings after account keybindings finish loading.
- Install the addon ZIP and `patch-Z.MPQ` as separate downloads; no EXE or build tool is needed.

### Changed

- Keep protected movement calls in FrameXML and never save keybindings automatically.

## 0.1.0 — 2026-08-04

### Added

- Port Left Interact to WoW 1.12 and Interface 11200.
- Use reversible session-only binding changes.
- Preserve newer mouse-binding changes made by another addon during normal disable or logout.
- Preserve original bindings across `/reload` and add `/leftinteract recover`.
- Support combined movement and the stock `MOVEFORWARD` fallback.
- Restore native left click while an inventory item is attached to the cursor.
- Include settings and What's New pages.
