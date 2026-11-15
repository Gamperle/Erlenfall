"""Checks provenance.py with small sample data. Run: python3 tools/asset_pipeline/test_provenance.py

The GPU pipelines can't run in CI, so this builds a tiny fake repository (an ASSETS.md, a batch file,
and a prop) and runs backfill, validation, and the stage-writing code the pipeline scripts use.
"""
import json
import os
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provenance

SOURCE = "FLUX.2 klein 4B, TRELLIS.2 (Comfy-Org int8 build) in ComfyUI 0.43.0, BiRefNet, DINOv3, Blender 5.2"
ASSETS = """# Assets

| File | Source | Author | License | Notes |
| --- | --- | --- | --- | --- |
| `assets/props/barrel_2.glb` | %s | AI-generated, chosen by Someone | CC BY-SA 4.0 | Seed 6002, subject: "upright oak barrel". TRELLIS.2 at its face budget; scaled to 1 m. Darkened by hand (issue #1) |
| `assets/props/rock_1.glb` | FLUX.2 klein 4B, TripoSR `107cefd`, rembg u2net, Blender 5.2 | AI-generated, chosen by Someone | CC BY-SA 4.0 | Seed 6011, subject: "grey rock". Automatic cleanup; scaled to 0.5 m |
| `assets/textures/*_relief.png` | Poly Haven | A | CC0 | Built by a script |

The generated props share one prompt, with the subject in place of `{}`: "A single {}, 3d game prop. No text." Drawn at 1024 x 1024 with 4 steps and guidance 1.0. See the pipeline.
""" % SOURCE
BATCH = {"seed": 6000, "objects": {"barrel": {"subject": "upright oak barrel", "faces": 2500, "meters": 1.0},
                                   "rock": {"subject": "grey rock", "faces": 900, "meters": 0.5}}}


def write(path, text):
    with open(path, "w", encoding="utf-8") as file:
        file.write(text)


def make_repo():
    root = tempfile.mkdtemp()
    os.makedirs(os.path.join(root, "tools", "asset_pipeline", "batches"))
    os.makedirs(os.path.join(root, "assets", "props"))
    for name in ("barrel_2", "rock_1"):
        write(os.path.join(root, "assets", "props", name + ".glb"), "")
    write(os.path.join(root, "ASSETS.md"), ASSETS)
    write(os.path.join(root, "tools", "asset_pipeline", "batches", "b1.json"), json.dumps(BATCH))
    return root


def quiet(lines):
    return lambda text: lines.append(text)


class BackfillTest(unittest.TestCase):
    def setUp(self):
        self.root = make_repo()
        self.out = []

    def test_backfill_uses_only_recorded_data(self):
        self.assertEqual(provenance.backfill(self.root, out=quiet(self.out)), 0)
        record = provenance.load(provenance.record_path("ai_prop", "assets/props/barrel_2.glb", self.root))
        self.assertEqual(record["seed"], 6002)
        self.assertEqual(record["batch"], "b1")
        self.assertEqual(record["stages"][0]["candidate"], 2)
        self.assertEqual(record["prompt"], "A single upright oak barrel, 3d game prop. No text.")
        self.assertEqual([s["step"] for s in record["stages"]], ["image", "mesh", "size"])
        self.assertEqual(record["stages"][1]["versions"], {"ComfyUI": "0.43.0"})
        self.assertEqual(record["stages"][1]["faces"], 2500)
        self.assertEqual(record["stages"][2]["meters"], 1.0)
        self.assertEqual(record["manual_edits"][0]["text"], "Darkened by hand (issue #1)")
        # Not recorded anywhere, so it stays null instead of being made up.
        self.assertIsNone(record["stages"][0]["date"])
        self.assertEqual(record["stages"][0]["versions"], {})

    def test_triposr_row_gets_a_cleanup_stage(self):
        provenance.backfill(self.root, out=quiet(self.out))
        record = provenance.load(provenance.record_path("ai_prop", "assets/props/rock_1.glb", self.root))
        self.assertEqual([s["step"] for s in record["stages"]], ["image", "mesh", "cleanup", "size"])
        self.assertEqual(record["stages"][1]["versions"], {"TripoSR": "107cefd"})
        self.assertEqual(record["manual_edits"], [])

    def test_backfill_does_not_overwrite(self):
        provenance.backfill(self.root, out=quiet(self.out))
        path = provenance.record_path("ai_prop", "assets/props/barrel_2.glb", self.root)
        record = provenance.load(path)
        record["manual_edits"].append({"text": "by hand", "date": "2026-01-01"})
        provenance.save(path, record)
        provenance.backfill(self.root, out=quiet(self.out))
        self.assertEqual(len(provenance.load(path)["manual_edits"]), 2)

    def test_seed_that_no_batch_explains_is_not_backfilled(self):
        text = ASSETS.replace("Seed 6002", "Seed 6999")
        write(os.path.join(self.root, "ASSETS.md"), text)
        self.assertEqual(provenance.backfill(self.root, out=quiet(self.out)), 1)
        self.assertFalse(os.path.exists(provenance.record_path("ai_prop", "assets/props/barrel_2.glb", self.root)))


class ValidateTest(unittest.TestCase):
    def setUp(self):
        self.root = make_repo()
        self.out = []
        provenance.backfill(self.root, out=quiet(self.out))
        self.out.clear()

    def run_validate(self):
        self.out.clear()
        return provenance.validate(self.root, out=quiet(self.out))

    def test_backfilled_records_are_valid(self):
        self.assertEqual(self.run_validate(), 0, self.out)

    def test_missing_record_is_reported(self):
        os.remove(provenance.record_path("ai_prop", "assets/props/rock_1.glb", self.root))
        self.assertEqual(self.run_validate(), 1)
        self.assertIn("rock_1.glb is AI-generated but has no provenance record", self.out[0])

    def test_seed_disagreeing_with_ledger_is_reported(self):
        path = provenance.record_path("ai_prop", "assets/props/barrel_2.glb", self.root)
        record = provenance.load(path)
        record["seed"] = 1
        provenance.save(path, record)
        self.assertEqual(self.run_validate(), 1)
        self.assertTrue(any("differs from ASSETS.md" in line for line in self.out))

    def test_record_for_missing_asset_is_reported(self):
        os.remove(os.path.join(self.root, "assets", "props", "rock_1.glb"))
        self.assertEqual(self.run_validate(), 1)
        self.assertTrue(any("does not exist" in line for line in self.out))

    def test_bad_json_is_reported(self):
        write(provenance.record_path("ai_prop", "assets/props/x.glb", self.root), "{")
        self.assertEqual(self.run_validate(), 1)

    def test_pipeline_record_needs_dates_and_versions(self):
        record = provenance.load(provenance.record_path("ai_prop", "assets/props/barrel_2.glb", self.root))
        record["origin"] = "pipeline"
        problems = provenance.check_record(record, "barrel_2")
        self.assertIn("stage image has no date", problems)
        self.assertIn("stage image has no tool versions", problems)


class PipelineStagesTest(unittest.TestCase):
    """The calls draw_klein.py, make_trellis.py, and size_glb.py make, in that order."""

    def test_three_scripts_build_one_valid_record(self):
        folder = tempfile.mkdtemp()
        path = os.path.join(folder, "barrel_2.json")
        provenance.add_stage(
            path, {"step": "image", "tool": "FLUX.2 klein 4B", "versions": {"torch": "2.14"}, "date": "2026-11-14", "candidate": 2},
            kind="ai_prop", asset="assets/props/barrel_2.glb", batch="b1", object="barrel", name="barrel_2",
            subject="upright oak barrel", prompt="A single upright oak barrel, 3d game prop.", seed=6002)
        provenance.add_stage(
            path, {"step": "mesh", "tool": "TRELLIS.2", "versions": {"ComfyUI": "0.43.0"}, "date": "2026-11-14"},
            kind="ai_prop", asset="assets/props/barrel_2.glb", batch="b1", object="barrel", name="barrel_2", subject="upright oak barrel")
        record = provenance.add_stage(
            path, {"step": "size", "tool": "Blender", "versions": {"Blender": "5.2.0"}, "date": "2026-11-14", "meters": 1.0},
            kind="ai_prop", asset="assets/props/barrel_2.glb", name="barrel_2")
        self.assertEqual(provenance.check_record(record, "barrel_2"), [])
        # Making the same object again replaces its stage and keeps the earlier ones.
        again = provenance.add_stage(path, {"step": "mesh", "tool": "TRELLIS.2", "versions": {"ComfyUI": "0.44"}, "date": "2026-11-15"}, kind="ai_prop")
        self.assertEqual([s["step"] for s in again["stages"]], ["image", "mesh", "size"])
        self.assertEqual(again["seed"], 6002)

    def test_stages_out_of_order_are_reported_by_validation(self):
        record = provenance.new_record("ai_prop", "assets/props/a_1.glb", batch="b", name="a_1", subject="a", prompt="a", seed=1)
        for step in ("size", "image", "mesh"):
            record["stages"].append({"step": step, "tool": "t", "versions": {"x": "1"}, "date": "2026-11-14"})
        self.assertIn("stages are out of order", provenance.check_record(record, "a_1"))


if __name__ == "__main__":
    unittest.main()
