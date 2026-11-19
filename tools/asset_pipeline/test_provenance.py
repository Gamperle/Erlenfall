"""Checks provenance.py with small sample data. Run: python3 tools/asset_pipeline/test_provenance.py

The GPU pipelines can't run in CI, so this builds a tiny fake repository (an ASSETS.md, a batch file,
and a prop) and runs backfill, validation, and the stage-writing code the pipeline scripts use.
"""
import json
import hashlib
import os
import struct
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import provenance
import shrink_textures

SOURCE = "FLUX.2 klein 4B, TRELLIS.2 (Comfy-Org int8 build) in ComfyUI 0.43.0, BiRefNet, DINOv3, Blender 5.2"
ASSETS = """# Assets

| File | Source | Author | License | Notes |
| --- | --- | --- | --- | --- |
| `assets/props/barrel_2.glb` | %s | AI-generated, chosen by Someone | CC BY-SA 4.0 | Seed 6002, subject: "upright oak barrel". TRELLIS.2 at its face budget; scaled to 1 m. Darkened by hand (issue #1) |
| `assets/props/rock_1.glb` | FLUX.2 klein 4B, TripoSR `107cefd`, rembg u2net, Blender 5.2 | AI-generated, chosen by Someone | CC BY-SA 4.0 | Seed 6011, subject: "grey rock". Automatic cleanup; scaled to 0.5 m |
| `assets/characters/hero.glb` | Built with [MPFB](https://x.example) from [MakeHuman asset packs](https://x.example/packs): system assets, Shirts 01 | MakeHuman | CC0 | Recipe in `villagers.json` |
| `assets/textures/grass.jpg` | [Poly Haven: sparse_grass](https://polyhaven.com/a/sparse_grass) | A | CC0 | 1K diffuse map, unedited |
| `assets/textures/*_relief.png` | The same Poly Haven texture as each photo above | A | CC0 | Built by a script |
| `assets/ui/panel.png`, `assets/ui/button_*.png` | Built by `tools/ui_pipeline/build_ui_textures.py` from `assets/textures/grass.jpg` | A | CC0 | Resized |
| `assets/ui/fonts/Some.ttf` | [Noto fonts](https://x.example) | Google | OFL | Unedited |

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
    for path in ("characters/hero.glb", "textures/grass.jpg", "textures/grass_relief.png", "ui/panel.png", "ui/button_a.png", "ui/button_b.png", "ui/fonts/Some.ttf"):
        os.makedirs(os.path.dirname(os.path.join(root, "assets", path)), exist_ok=True)
        write(os.path.join(root, "assets", path), "x")
    os.makedirs(os.path.join(root, "tools", "character_pipeline"))
    write(os.path.join(root, "tools", "character_pipeline", "villagers.json"), json.dumps([{"id": "hero", "skin": "plain"}]))
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


def write_ui_records(root):
    """What build_ui_textures.py writes, for the three UI files the sample repository has."""
    for name in ("panel", "button_a", "button_b"):
        asset = "assets/ui/%s.png" % name
        stage = {"step": "build", "tool": "build_ui_textures.py", "date": "2026-11-17", "versions": {"Pillow": "12"}}
        provenance.save(provenance.record_path("ui_texture", asset, root), provenance.new_record("ui_texture", asset, name=name, stages=[stage]))


class OtherAssetsBackfillTest(unittest.TestCase):
    def setUp(self):
        self.root = make_repo()
        self.out = []
        provenance.backfill(self.root, out=quiet(self.out))

    def test_character_and_relief_records_use_nulls_for_the_unknown(self):
        hero = provenance.load(provenance.record_path("character", "assets/characters/hero.glb", self.root))
        self.assertEqual(hero["origin"], "backfill")
        self.assertEqual(hero["stages"][0]["recipe"], {"id": "hero", "skin": "plain"})
        self.assertEqual(hero["stages"][0]["asset_packs"], ["system assets", "Shirts 01"])
        self.assertIsNone(hero["stages"][0]["date"])
        self.assertEqual(hero["stages"][0]["output_sha256"], provenance.sha256(os.path.join(self.root, "assets/characters/hero.glb")))
        relief = provenance.load(provenance.record_path("derived_texture", "assets/textures/grass_relief.png", self.root))
        self.assertEqual(relief["stages"][0]["polyhaven_asset"], "sparse_grass")
        self.assertIsNone(relief["stages"][0]["date"])
        self.assertEqual(provenance.check_record(relief, "grass_relief"), [])

    def test_relief_map_without_a_known_source_is_not_backfilled(self):
        write(os.path.join(self.root, "assets", "textures", "mystery_relief.png"), "x")
        self.assertEqual(provenance.backfill(self.root, out=quiet(self.out)), 1)
        self.assertFalse(os.path.exists(provenance.record_path("derived_texture", "assets/textures/mystery_relief.png", self.root)))

    def test_character_without_a_recipe_is_not_backfilled(self):
        write(os.path.join(self.root, "tools", "character_pipeline", "villagers.json"), "[]")
        os.remove(provenance.record_path("character", "assets/characters/hero.glb", self.root))
        self.assertEqual(provenance.backfill(self.root, out=quiet(self.out)), 1)


class ValidateTest(unittest.TestCase):
    def setUp(self):
        self.root = make_repo()
        self.out = []
        provenance.backfill(self.root, out=quiet(self.out))
        write_ui_records(self.root)
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

    def test_missing_character_relief_or_ui_record_is_reported(self):
        for kind, asset in (("character", "assets/characters/hero.glb"), ("derived_texture", "assets/textures/grass_relief.png"),
                            ("ui_texture", "assets/ui/button_b.png")):
            path = provenance.record_path(kind, asset, self.root)
            saved = provenance.load(path)
            os.remove(path)
            self.assertEqual(self.run_validate(), 1, asset)
            self.assertTrue(any(asset in line and "has no provenance record" in line for line in self.out), self.out)
            provenance.save(path, saved)
        self.assertEqual(self.run_validate(), 0, self.out)

    def test_ui_font_needs_no_record(self):
        self.assertEqual(self.run_validate(), 0, self.out)

    def test_pattern_matching_no_file_is_reported(self):
        os.remove(os.path.join(self.root, "assets", "ui", "button_a.png"))
        os.remove(os.path.join(self.root, "assets", "ui", "button_b.png"))
        os.remove(provenance.record_path("ui_texture", "assets/ui/button_a.png", self.root))
        os.remove(provenance.record_path("ui_texture", "assets/ui/button_b.png", self.root))
        self.assertEqual(self.run_validate(), 1)
        self.assertTrue(any("button_*.png" in line for line in self.out))

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


class TrellisModelsTest(unittest.TestCase):
    """The weight files the mesh stage names (#450)."""

    WORKFLOW = {"15": {"class_type": "CLIPVisionLoader", "inputs": {"clip_name": "dino_v3_L_naf_fp32.safetensors"}},
                "193": {"class_type": "LoadBackgroundRemovalModel", "inputs": {"bg_removal_name": "birefnet.safetensors"}},
                "40": {"class_type": "UNETLoader", "inputs": {"unet_name": "missing.safetensors", "weight_dtype": "default"}},
                "122": {"class_type": "LoadImage", "inputs": {"image": "pic.png"}}}

    def stage(self, models):
        return {"step": "mesh", "tool": "TRELLIS.2", "versions": {"ComfyUI": "0.43.0"}, "date": "2026-11-14", "models": models}

    def test_workflow_models_hashes_found_files_and_never_guesses(self):
        folder = tempfile.mkdtemp()
        os.makedirs(os.path.join(folder, "clip_vision"))
        with open(os.path.join(folder, "clip_vision", "dino_v3_L_naf_fp32.safetensors"), "wb") as file:
            file.write(b"abc")
        models = {m["file"]: m for m in provenance.workflow_models(self.WORKFLOW, folder)}
        self.assertEqual(sorted(models), ["birefnet.safetensors", "dino_v3_L_naf_fp32.safetensors", "missing.safetensors"])
        dino = models["dino_v3_L_naf_fp32.safetensors"]
        self.assertEqual((dino["node"], dino["class"], dino["input"], dino["path"], dino["size"]),
                         ("15", "CLIPVisionLoader", "clip_name", "clip_vision/dino_v3_L_naf_fp32.safetensors", 3))
        self.assertEqual(dino["sha256"], hashlib.sha256(b"abc").hexdigest())
        missing = models["missing.safetensors"]
        self.assertEqual((missing["path"], missing["size"], missing["sha256"]), (None, None, None))

    def test_validation(self):
        good = {"file": "a.safetensors", "size": 3, "sha256": "a" * 64}
        cases = (("pipeline", [good], ""), ("pipeline", None, "null models"), ("pipeline", [{"file": "a", "size": None, "sha256": None}], "no size or SHA-256"),
                 ("pipeline", [], "non-empty list"), ("backfill", None, ""), ("backfill", [good], ""), ("backfill", "x", "non-empty list"))
        for origin, models, expected in cases:
            problems = " ".join(provenance.check_models(self.stage(models), origin))
            if expected:
                self.assertIn(expected, problems)
            else:
                self.assertEqual(problems, "")
        stage = self.stage(None)
        del stage["models"]
        self.assertIn("no models", provenance.check_models(stage, "backfill")[0])

    def test_backfilled_trellis_stage_has_null_models(self):
        stages = provenance.tool_stage("FLUX.2 klein 4B, TRELLIS.2 (Comfy-Org int8 build) in ComfyUI 0.43.0, BiRefNet, DINOv3, Blender 5.2")
        mesh = next(s for s in stages if s["step"] == "mesh")
        self.assertIn("models", mesh)
        self.assertIsNone(mesh["models"])


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
            path, {"step": "mesh", "tool": "TRELLIS.2", "versions": {"ComfyUI": "0.43.0"}, "date": "2026-11-14",
                  "models": [{"node": "40", "class": "UNETLoader", "input": "unet_name", "file": "trellis_2_int8_convrot.safetensors",
                              "path": "diffusion_models/trellis_2_int8_convrot.safetensors", "size": 5253048192, "sha256": "d" * 64}]},
            kind="ai_prop", asset="assets/props/barrel_2.glb", batch="b1", object="barrel", name="barrel_2", subject="upright oak barrel",
            chosen_by="Someone")
        record = provenance.add_stage(
            path, {"step": "size", "tool": "Blender", "versions": {"Blender": "5.2.0"}, "date": "2026-11-14", "meters": 1.0},
            kind="ai_prop", asset="assets/props/barrel_2.glb", name="barrel_2")
        self.assertEqual(provenance.check_record(record, "barrel_2"), [])
        del record["chosen_by"]
        self.assertIn("chosen_by is missing", " ".join(provenance.check_record(record, "barrel_2")))
        # Making the same object again replaces its stage and keeps the earlier ones.
        again = provenance.add_stage(path, {"step": "mesh", "tool": "TRELLIS.2", "versions": {"ComfyUI": "0.44"}, "date": "2026-11-15", "models": record["stages"][1]["models"]}, kind="ai_prop")
        self.assertEqual([s["step"] for s in again["stages"]], ["image", "mesh", "size"])
        self.assertEqual(again["seed"], 6002)

    def test_triposr_scripts_build_one_valid_record(self):
        """The calls run_triposr.py and cleanup_mesh.py make, then size_glb.py."""
        path = os.path.join(tempfile.mkdtemp(), "rock_1.json")
        common = {"kind": "ai_prop", "asset": "assets/props/rock_1.glb", "name": "rock_1", "chosen_by": "Someone"}
        provenance.add_stage(path, {"step": "image", "tool": "FLUX.2 klein 4B", "versions": {"torch": "2.14"}, "date": "2026-11-14"},
                             batch="b1", object="rock", subject="grey rock", prompt="A single grey rock.", seed=6011, **common)
        provenance.add_stage(path, {"step": "size", "tool": "Blender", "versions": {"Blender": "5.2"}, "date": "2026-11-15"}, **common)
        provenance.add_stage(path, {"step": "cleanup", "tool": "Automatic cleanup (cleanup_mesh.py)", "versions": {"Blender": "5.2"}, "date": "2026-11-15"}, **common)
        record = provenance.add_stage(path, {"step": "mesh", "tool": "TripoSR", "versions": {"TripoSR": "107cefd", "torch": "2.14"}, "date": "2026-11-14"}, **common)
        self.assertEqual([s["step"] for s in record["stages"]], ["image", "mesh", "cleanup", "size"])
        self.assertEqual(provenance.check_record(record, "rock_1"), [])

    def test_stages_out_of_order_are_reported_by_validation(self):
        record = provenance.new_record("ai_prop", "assets/props/a_1.glb", batch="b", name="a_1", subject="a", prompt="a", seed=1)
        for step in ("size", "image", "mesh"):
            record["stages"].append({"step": step, "tool": "t", "versions": {"x": "1"}, "date": "2026-11-14"})
        self.assertIn("stages are out of order", provenance.check_record(record, "a_1"))


def fake_png(edge):
    """A PNG header with this size; the check reads only the header."""
    return b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", edge, edge) + b"\x08\x02\0\0\0"


def write_glb(path, meters, edges):
    """A one-triangle GLB whose longest side is meters, with a PNG of each edge as an embedded image."""
    binary = b"".join(fake_png(e) for e in edges)
    views = [{"buffer": 0, "byteOffset": i * 29, "byteLength": 29} for i in range(len(edges))]
    document = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0}],
                "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}],
                "accessors": [{"min": [0, 0, 0], "max": [meters, 0.1, 0.1]}], "bufferViews": views,
                "images": [{"bufferView": i, "mimeType": "image/png"} for i in range(len(edges))],
                "buffers": [{"byteLength": len(binary)}]}
    shrink_textures.write_glb(path, document, binary)


class TextureTierTest(unittest.TestCase):
    def setUp(self):
        self.root = make_repo()
        self.props = os.path.join(self.root, "assets", "props")

    def test_tier_from_size(self):
        self.assertEqual(shrink_textures.texture_edge(1.25), 512)
        self.assertEqual(shrink_textures.texture_edge(1.26), 1024)

    def test_small_prop_at_1024_is_reported(self):
        write_glb(os.path.join(self.props, "bowl_1.glb"), 0.2, [512, 1024])
        problems = shrink_textures.check_props(self.root)
        self.assertEqual(len(problems), 1)
        self.assertIn("bowl_1.glb: texture 1 is 1024 x 1024 px, above the 512 px", problems[0])

    def test_right_sizes_pass(self):
        write_glb(os.path.join(self.props, "bowl_1.glb"), 0.2, [512, 256])
        write_glb(os.path.join(self.props, "house_1.glb"), 4.0, [1024, 1024])
        self.assertEqual(shrink_textures.check_props(self.root), [])

    def test_large_prop_at_2048_is_reported(self):
        write_glb(os.path.join(self.props, "house_1.glb"), 4.0, [2048])
        self.assertEqual(len(shrink_textures.check_props(self.root)), 1)

    def test_lfs_pointer_is_skipped(self):
        write(os.path.join(self.props, "bowl_1.glb"), "version https://git-lfs.github.com/spec/v1\n")
        self.assertEqual(shrink_textures.check_props(self.root), [])

    def test_validate_fails_on_oversized_textures(self):
        out = []
        provenance.backfill(self.root, out=quiet(out))
        write_glb(os.path.join(self.props, "bowl_1.glb"), 0.2, [1024])
        out.clear()
        self.assertEqual(provenance.validate(self.root, out=quiet(out)), 1)
        self.assertTrue(any("bowl_1.glb" in line for line in out), out)


if __name__ == "__main__":
    unittest.main()
