# Example mod

`cozy_torches` is a small working mod. It makes torches burn out after 300 seconds, doubles health regeneration, doubles the butterflies, and hides the minimap.

To try it, copy the contents of this folder (`load_order.json` and `cozy_torches/`) into the game's `user://mods` folder. If you already have mods, copy only `cozy_torches/` and add `"cozy_torches"` to your own `load_order.json`. [The mod guide](../MODS.md) says where that folder is and lists every rule.

The game never loads this folder from here. The smoke test (`tests/smoke_test.gd`) loads it and checks the result, so it stays correct as flags change.
