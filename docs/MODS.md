# Mods

Mods are data only. The game reads their files and never runs their code. At the moment a mod can override [feature flags](FEATURE_FLAGS.md); items, recipes, and quests will follow ([#52](https://github.com/Gamperle/Erlenfall/issues/52)).

## Where mods go

Mods live in the `mods` folder of the game's user data folder (`user://mods`). On Linux that is `~/.local/share/godot/app_userdata/<project name>/mods`.

```
mods/
	load_order.json
	faster_torches/
		feature_flags.json
```

`load_order.json` lists the mod folders from first to last:

```json
{ "mods": ["faster_torches", "other_mod"] }
```

Each mod's `feature_flags.json` uses the [flag file format](FEATURE_FLAGS.md#file-format). The base file is applied first, then each mod in the order listed, so the last mod to set a flag or value wins.

## Rules and errors

- A mod is only loaded if it is listed. Folders not in the list are ignored.
- Names must be plain folder names. Names with `/`, `\`, or `:`, or starting with `.`, are skipped.
- Mods load once, when the game first reads a flag.

## When a mod is broken

A broken mod never stops the game or changes it halfway. Each listed mod gets a load result in `ModLoader.results`: `ok`, `skipped` (the mod was not loaded), or `error` (its file was unusable). Every problem names the mod, the file, and the reason.

| Problem | What happens |
|---|---|
| `load_order.json` is not valid JSON or not an object with a `mods` list | `error`, no mods load |
| A listed name is invalid, listed twice, has no folder, or has no `feature_flags.json` | `skipped`; the other mods still load |
| `feature_flags.json` is not valid JSON (the message gives the line), is not an object, or `flags` or `values` is not an object | `error`; nothing from that file is applied |
| An unknown top-level key (only `flags` and `values` exist) | ignored; the rest of the file applies |
| A flag that is not `true`/`false`, a flag name, or a valid rule, or a value that is not a number, text, or `true`/`false` | that one entry is ignored; the rest of the file applies |

Where you see the results:

- **Log file:** errors are logged as errors and everything else as warnings, for example `Mod faster_torches (feature_flags.json): error, invalid JSON at line 3: ...`. Godot writes the log to `user://logs/godot.log` (on Linux `~/.local/share/godot/app_userdata/<project name>/logs`). On Windows and the Web, use the in-game list below.
- **In game:** a short notice when the game starts says how many mod problems there are, and the settings screen lists each one under "Mod problems".

The code is in `scripts/mod_loader.gd`.

## Checking data

`DataValidator` (`scripts/data_validator.gd`) checks the JSON files in `data/` for missing fields, wrong types, and unknown item, quest, objective, villager, station, or dialogue node ids. Every problem is one line naming the file and the exact entry. The game logs them at startup, and the smoke test (so CI) fails on them. To check a mod's data folder against the game's:

```
godot --headless --path . --script res://tools/validate_data.gd -- /path/to/mod res://data
```
