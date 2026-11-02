"""Runs TripoSR's run.py with cuDNN off. Run it from the TripoSR folder, with run.py's arguments.

With cuDNN off, a large MIOpen DLL no longer loads, the first convolution takes 0.16 s rather than 10.9 s,
and the output is practically unchanged. Whether this prevents the startup crash isn't known (issue #59).
"""
import faulthandler
import runpy
import sys

import torch

faulthandler.enable()
torch.backends.cudnn.enabled = False
sys.path.insert(0, ".")
sys.argv = ["run.py"] + sys.argv[1:]
runpy.run_path("run.py", run_name="__main__")
