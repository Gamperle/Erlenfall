import sys

import trimesh

mesh = trimesh.load(sys.argv[1], force="mesh")
print("vertices:", len(mesh.vertices), "faces:", len(mesh.faces))
print("watertight:", mesh.is_watertight, "volume:", round(float(mesh.volume), 5))
print("bounds:", mesh.bounds.round(3).tolist())
print("has vertex colors:", mesh.visual.kind)
