"""Stand-in for torchmcubes, whose build fails against the ROCm PyTorch on Windows.

Same call and vertex order as torchmcubes.marching_cubes, using scikit-image on the CPU.
"""
import numpy as np
import torch
from skimage import measure


def marching_cubes(volume, thresh):
    # TripoSR negates density, so values below the threshold are inside the object.
    vol = volume.detach().float().cpu().numpy()
    verts, faces, _, _ = measure.marching_cubes(vol, level=thresh, gradient_direction="ascent")
    verts = verts[:, [2, 1, 0]].astype(np.float32)
    return torch.from_numpy(verts.copy()), torch.from_numpy(faces.astype(np.int64))
