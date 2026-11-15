#!/usr/bin/env python3
"""Provenance records for generated assets (#273).

Every generated asset gets one small JSON file in provenance/<kind>/<name>.json at the repository root
(not under assets/, which ASSETS.md must account for file by file). It records how the asset was made:
the prompt and seed, each tool and its version, the dates, and any manual edits.

The pipeline scripts import this module to write records. It uses only the standard library, so it also
runs inside Blender's Python and on the asset PC, where the scripts are copied flat next to it.

Command line, from the repository root:
  provenance.py validate             check every record and compare with ASSETS.md (exit 1 on problems)
  provenance.py backfill [--force]   write records for AI-generated props from what ASSETS.md records
  provenance.py note ASSET TEXT      add a manual edit to an asset's record

A record, as JSON:
  schema        1
  asset         "assets/props/anvil_2.glb"
  kind          "ai_prop", "character" or "derived_texture"
  origin        "pipeline" if a script wrote it as the asset was made, or "backfill" if it was rebuilt
                from ASSETS.md afterwards. A backfilled record has null for what ASSETS.md doesn't say
  stages        what ran, in order: {"step", "tool", "versions", "date", plus the step's settings}
  manual_edits  [{"text", "date"}] for changes made by hand after the pipeline. Empty if none are known
  ai_prop also has: batch, object, name, chosen_by, subject, prompt, seed
"""
import datetime
import hashlib
import json
import os
import re
import sys

SCHEMA = 1
KINDS = ("ai_prop", "character", "derived_texture")
PROP_STEPS = ("image", "mesh", "cleanup", "size")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
# The kind decides the folder under provenance/.
FOLDERS = {"ai_prop": "props", "character": "characters", "derived_texture": "textures"}


def today():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as file:
        for block in iter(lambda: file.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def read_text(path):
    with open(path, encoding="utf-8") as file:
        return file.read()


def load(path):
    with open(path, encoding="utf-8") as file:
        return json.load(file)


def save(path, record):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as file:
        json.dump(record, file, indent="\t", ensure_ascii=False)
        file.write("\n")


def new_record(kind, asset, origin="pipeline", **fields):
    record = {"schema": SCHEMA, "asset": asset, "kind": kind, "origin": origin}
    record.update(fields)
    record.setdefault("stages", [])
    record.setdefault("manual_edits", [])
    return record


def add_stage(path, stage, **top_level):
    """Adds a stage to the record file at path, making the file if needed. A stage with the same step
    replaces the old one, so a rerun doesn't pile up copies. Keyword arguments set top-level fields."""
    record = load(path) if os.path.exists(path) else new_record(top_level.pop("kind", "ai_prop"), top_level.pop("asset", ""))
    record.update(top_level)
    stages = [s for s in record["stages"] if s.get("step") != stage["step"]] + [stage]
    # Steps can be redone in any order (a model remade after sizing), but the record lists them in making order.
    order = {step: i for i, step in enumerate(PROP_STEPS)}
    record["stages"] = sorted(stages, key=lambda s: order.get(s.get("step"), len(order)))
    save(path, record)
    return record


def record_path(kind, asset, root=ROOT):
    return os.path.join(root, "provenance", FOLDERS[kind], os.path.splitext(os.path.basename(asset))[0] + ".json")


def module_version(name):
    try:
        import importlib.metadata

        return importlib.metadata.version(name)
    except Exception:
        return None


# --- Validation ---------------------------------------------------------------------------------


def check_record(record, name=""):
    """Returns the problems in one record. name is the file's base name, which must match the asset."""
    found = []
    if not isinstance(record, dict):
        return ["is not a JSON object"]
    if record.get("schema") != SCHEMA:
        found.append("schema is not %d" % SCHEMA)
    kind = record.get("kind")
    if kind not in KINDS:
        found.append("kind is not one of %s" % ", ".join(KINDS))
    asset = record.get("asset")
    if not isinstance(asset, str) or not asset.startswith("assets/"):
        found.append("asset is not a path under assets/")
    elif name and os.path.splitext(os.path.basename(asset))[0] != name:
        found.append("file name does not match asset %s" % asset)
    origin = record.get("origin")
    if origin not in ("pipeline", "backfill"):
        found.append("origin is not pipeline or backfill")
    if not isinstance(record.get("manual_edits"), list):
        found.append("manual_edits is not a list")
    else:
        for edit in record["manual_edits"]:
            if not (isinstance(edit, dict) and edit.get("text")):
                found.append("a manual edit has no text")
    stages = record.get("stages")
    if not isinstance(stages, list) or not stages:
        return found + ["has no stages"]
    for stage in stages:
        if not (isinstance(stage, dict) and stage.get("step") and stage.get("tool")):
            found.append("a stage has no step or tool")
        elif origin == "pipeline":
            if not stage.get("date"):
                found.append("stage %s has no date" % stage["step"])
            if not stage.get("versions"):
                found.append("stage %s has no tool versions" % stage["step"])
    if kind == "ai_prop":
        for key in ("prompt", "subject", "name", "batch"):
            if not record.get(key):
                found.append("%s is missing" % key)
        if not isinstance(record.get("seed"), int):
            found.append("seed is not an integer")
        steps = [s.get("step") for s in stages if isinstance(s, dict)]
        for step in steps:
            if step not in PROP_STEPS:
                found.append("unknown step %s" % step)
        if steps != sorted(steps, key=lambda s: PROP_STEPS.index(s) if s in PROP_STEPS else 99):
            found.append("stages are out of order")
        for needed in ("image", "mesh"):
            if needed not in steps:
                found.append("has no %s stage" % needed)
        if record.get("prompt") and record.get("subject") and record["subject"] not in record["prompt"]:
            found.append("prompt does not contain the subject")
    return found


# --- ASSETS.md ----------------------------------------------------------------------------------


def ledger_rows(text):
    """Yields (paths, cells) for each ASSETS.md table row. cells[0] is the file column."""
    for line in text.split("\n"):
        if not line.startswith("| `"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split(" | ")]
        if len(cells) >= 5:
            yield re.findall(r"`([^`]+)`", cells[0]), cells


def shared_prompt(text):
    """The style prompt ASSETS.md gives for generated props, as {subject} format string, and its size."""
    found = re.search(r"with the subject in place of `\{\}`: \"(.+?)\"\.? Drawn at (\d+) x (\d+) with (\d+) steps and guidance (\d+(?:\.\d+)?)", text)
    if not found:
        return None
    return {"template": found.group(1).replace("{}", "{subject}"), "width": int(found.group(2)), "height": int(found.group(3)),
            "steps": int(found.group(4)), "guidance": float(found.group(5))}


def load_batches(root=ROOT):
    folder = os.path.join(root, "tools", "asset_pipeline", "batches")
    return {f[:-5]: load(os.path.join(folder, f)) for f in sorted(os.listdir(folder)) if f.endswith(".json")}


def find_batch(batches, name, seed, subject):
    """The batch and object that the seed, name and subject all agree on, or None."""
    obj = name.rsplit("_", 1)[0]
    for batch, config in batches.items():
        item = config["objects"].get(obj)
        index = list(config["objects"]).index(obj) if item else -1
        if item and item["subject"] == subject and 0 <= seed - config["seed"] - index * 10 < 6:
            return batch, obj, item, seed - config["seed"] - index * 10
    return None


def tool_stage(source):
    """Splits the Source cell of a generated prop into the stages ASSETS.md lets us name."""
    tools = [t.strip() for t in re.split(r", (?![^()]*\))", source)]
    stages = []
    mesh_tools = []
    for tool in tools:
        if tool.startswith("FLUX"):
            stages.append({"step": "image", "tool": tool, "versions": {}})
        elif tool.startswith("TRELLIS") or tool.startswith("TripoSR"):
            stage = {"step": "mesh", "tool": tool, "versions": {}}
            found = re.search(r"in ComfyUI ([\d.]+)", tool)
            if found:
                stage["tool"] = re.sub(r" in ComfyUI [\d.]+", "", tool)
                stage["versions"]["ComfyUI"] = found.group(1)
            found = re.match(r"TripoSR `(\w+)`", tool)
            if found:
                stage["tool"] = "TripoSR"
                stage["versions"]["TripoSR"] = found.group(1)
            stages.append(stage)
        elif tool.startswith("Blender"):
            stages.append({"step": "size", "tool": "Blender", "versions": {"Blender": tool.split(" ", 1)[1]}})
        else:
            mesh_tools.append(tool.strip("`"))
    for stage in stages:
        if stage["step"] == "mesh":
            stage["helpers"] = mesh_tools
    return stages


def backfill_record(row, cells, prompt_info, batches):
    """A record for one generated prop's ASSETS.md row, or (None, reason). Nothing here is guessed:
    what the row doesn't say is null."""
    asset = row
    name = os.path.splitext(os.path.basename(asset))[0]
    notes = cells[4]
    seed = re.search(r"Seed (\d+), subject: \"(.+?)\"\.", notes)
    if not seed:
        return None, "notes have no seed and subject"
    seed_value, subject = int(seed.group(1)), seed.group(2)
    found = find_batch(batches, name, seed_value, subject)
    if not found:
        return None, "no batch file agrees with seed %d, subject and name" % seed_value
    batch, obj, item, candidate = found
    stages = tool_stage(cells[1])
    if not stages or stages[0]["step"] != "image":
        return None, "source has no image tool"
    chosen = re.match(r"AI-generated, chosen by (.+)", cells[2])
    for stage in stages:
        stage["date"] = None
        if stage["step"] == "image":
            stage.update({"width": prompt_info["width"], "height": prompt_info["height"], "steps": prompt_info["steps"],
                          "guidance": prompt_info["guidance"], "candidate": candidate})
        elif stage["step"] == "mesh" and stage["tool"].startswith("TRELLIS"):
            stage["faces"] = item["faces"]
        elif stage["step"] == "size":
            meters = re.search(r"scaled to ([\d.]+) m", notes)
            stage["meters"] = float(meters.group(1)) if meters else None
    if "Automatic cleanup" in notes:
        stages.insert(2, {"step": "cleanup", "tool": "Automatic cleanup (cleanup_mesh.py)", "versions": {}, "date": None})
    tail = re.search(r"scaled to [\d.]+ m\.?\s*(.*)$", notes)
    edits = [{"text": tail.group(1).strip(), "date": None}] if tail and tail.group(1).strip() else []
    return new_record(
        "ai_prop", asset, "backfill", batch=batch, object=obj, name=name, chosen_by=chosen.group(1) if chosen else None,
        subject=subject, prompt=prompt_info["template"].format(subject=subject), seed=seed_value, stages=stages, manual_edits=edits,
        backfill_note="Rebuilt from ASSETS.md and the batch file. Dates and tool versions it doesn't state are null."), None


def generated_rows(text):
    """(asset path, cells) for each row of ASSETS.md that names one AI-generated file, not a pattern."""
    for paths, cells in ledger_rows(text):
        if len(paths) == 1 and cells[1].startswith("FLUX") and "*" not in paths[0]:
            yield paths[0], cells


def backfill(root=ROOT, force=False, out=print):
    text = read_text(os.path.join(root, "ASSETS.md"))
    info = shared_prompt(text)
    if not info:
        out("ASSETS.md has no shared prompt paragraph, nothing to backfill")
        return 1
    batches = load_batches(root)
    written = skipped = failed = 0
    for asset, cells in generated_rows(text):
        path = record_path("ai_prop", asset, root)
        if os.path.exists(path) and not force:
            skipped += 1
            continue
        record, reason = backfill_record(asset, cells, info, batches)
        if record is None:
            out("not backfilled: %s: %s" % (asset, reason))
            failed += 1
            continue
        save(path, record)
        written += 1
    out("backfill: %d written, %d already there, %d not possible" % (written, skipped, failed))
    return 1 if failed else 0


def validate(root=ROOT, out=print):
    problems = []
    text = read_text(os.path.join(root, "ASSETS.md"))
    listed = {p for paths, _ in ledger_rows(text) for p in paths}
    folder = os.path.join(root, "provenance")
    seen = set()
    for current, _dirs, files in os.walk(folder):
        for file in sorted(files):
            if not file.endswith(".json"):
                continue
            path = os.path.join(current, file)
            label = os.path.relpath(path, root).replace(os.sep, "/")
            try:
                record = load(path)
            except ValueError as error:
                problems.append("%s: not valid JSON: %s" % (label, error))
                continue
            problems += ["%s: %s" % (label, p) for p in check_record(record, file[:-5])]
            asset = record.get("asset") if isinstance(record, dict) else None
            if isinstance(asset, str):
                seen.add(asset)
                if not os.path.exists(os.path.join(root, asset)):
                    problems.append("%s: asset %s does not exist" % (label, asset))
                if asset not in listed and not any(_glob_match(asset, p) for p in listed):
                    problems.append("%s: asset %s has no ASSETS.md row" % (label, asset))
    for asset, cells in generated_rows(text):
        if asset not in seen:
            problems.append("%s is AI-generated but has no provenance record (run backfill, or the pipeline)" % asset)
            continue
        record = load(record_path("ai_prop", asset, root))
        seed = re.search(r"Seed (\d+), subject: \"(.+?)\"\.", cells[4])
        if seed and (record.get("seed") != int(seed.group(1)) or record.get("subject") != seed.group(2)):
            problems.append("%s: seed or subject differs from ASSETS.md" % asset)
    for problem in problems:
        out(problem)
    out("provenance: %d problems" % len(problems) if problems else "provenance: ok, %d assets" % len(seen))
    return 1 if problems else 0


def _glob_match(path, pattern):
    import fnmatch

    return fnmatch.fnmatch(path, pattern)


def add_note(asset, text, root=ROOT):
    kind = "ai_prop" if "/props/" in asset else "character" if "/characters/" in asset else "derived_texture"
    path = record_path(kind, asset, root)
    record = load(path)
    record["manual_edits"].append({"text": text, "date": today()})
    save(path, record)


def main(argv):
    if not argv or argv[0] not in ("validate", "backfill", "note"):
        print(__doc__)
        return 2
    if argv[0] == "validate":
        return validate()
    if argv[0] == "backfill":
        return backfill(force="--force" in argv)
    if len(argv) != 3:
        print("usage: provenance.py note ASSET TEXT")
        return 2
    add_note(argv[1], argv[2])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
