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
- A mod that is missing, has no `feature_flags.json`, or is listed twice is skipped, with an error in the log. The other mods still load.
- A load order file that is not valid logs an error and no mods load.
- Mods load once, when the game first reads a flag.

The code is in `scripts/mod_loader.gd`.

## Checking data

`DataValidator` (`scripts/data_validator.gd`) checks the JSON files in `data/` for missing fields, wrong types, and unknown item, quest, objective, villager, station, or dialogue node ids. Every problem is one line naming the file and the exact entry. The game logs them at startup, and the smoke test (so CI) fails on them. To check a mod's data folder against the game's:

```
godot --headless --path . --script res://tools/validate_data.gd -- /path/to/mod res://data
```
