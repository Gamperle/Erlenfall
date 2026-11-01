#!/usr/bin/env bash
# Tests TripoSR on an AMD GPU through ROCm. See README.md. Usage: ./run_test.sh image.png
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 /path/to/object.png" >&2
	exit 1
fi
image="$(realpath "$1")"

work="$(dirname "$(realpath "$0")")/work"
mkdir -p "$work"
cd "$work"

if [[ ! -d TripoSR ]]; then
	git clone --depth 1 https://github.com/VAST-AI-Research/TripoSR.git
fi
if [[ ! -d venv ]]; then
	python3 -m venv venv
fi
# shellcheck disable=SC1091
source venv/bin/activate

pip install --upgrade pip
pip install torch torchvision --index-url https://download.pytorch.org/whl/rocm6.4
pip install -r TripoSR/requirements.txt

python - <<'EOF'
import torch
print("PyTorch:", torch.__version__)
print("ROCm:", getattr(torch.version, "hip", None))
available = torch.cuda.is_available()
print("GPU available:", available)
if available:
    print("GPU:", torch.cuda.get_device_name(0))
EOF

cd TripoSR
time python run.py "$image" --output-dir "$work/output" --bake-texture
echo "Model written to $work/output"
