"""Checks make_masks.py's ComfyUI workflow and that run_triposr.py's mask handling is wired in (no GPU, no server).
Run: python3 tools/asset_pipeline/test_make_masks.py"""
import os
import re
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_masks
import provenance


class MakeMasksTest(unittest.TestCase):
    def test_workflow_loads_birefnet_and_saves_the_mask(self):
        workflow = make_masks.mask_workflow("b_name_mask.png")
        self.assertEqual(workflow["1"]["inputs"]["image"], "b_name_mask.png")
        self.assertEqual(workflow["2"]["inputs"]["bg_removal_name"], "birefnet.safetensors")
        self.assertEqual(workflow["5"]["inputs"]["filename_prefix"], "masks/b_name_mask")

    def test_the_weight_file_is_named_with_its_hash(self):
        folder = tempfile.mkdtemp()
        os.makedirs(os.path.join(folder, "background_removal"))
        with open(os.path.join(folder, "background_removal", "birefnet.safetensors"), "wb") as f:
            f.write(b"weights")
        models = provenance.workflow_models(make_masks.mask_workflow("x.png"), folder)
        self.assertEqual([m["file"] for m in models], ["birefnet.safetensors"])
        self.assertEqual(models[0]["size"], 7)
        self.assertRegex(models[0]["sha256"], r"^[0-9a-f]{64}$")

    def test_run_triposr_creates_the_output_folder_and_takes_the_mask(self):
        """run_triposr.py needs torch, so check its source: the folder is made before run.py runs (#493), and --mask implies --no-remove-bg (#492)."""
        text = open(os.path.join(HERE, "run_triposr.py")).read()
        self.assertLess(text.index('os.makedirs(os.path.join(OUTPUT_DIR, "0")'), text.index("runpy.run_path"))
        self.assertTrue(re.search(r'sys\.argv\.append\("--no-remove-bg"\)', text))


if __name__ == "__main__":
    unittest.main()
