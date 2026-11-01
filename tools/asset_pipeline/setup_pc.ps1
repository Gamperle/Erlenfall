# Installs the asset pipeline into one folder on the Windows GPU PC. See docs/ASSET_PIPELINE.md.
# Run from a copy of tools/asset_pipeline. Needs Python 3.12 and Git. Doesn't need administrator rights.
param([string]$Root = 'D:\erlenfall-assets')

$here = $PSScriptRoot
New-Item -ItemType Directory -Force $Root, "$Root\tmp" | Out-Null
Copy-Item "$here\*" $Root -Force
Set-Location $Root
$env:PIP_CACHE_DIR = "$Root\pip-cache"
$env:TEMP = "$Root\tmp"
$env:TMP = $env:TEMP

$amd = 'https://stable.repo.amd.com/rocm/whl-next/'
$torch = 'torch[device-gfx1100]==2.14.0+rocm10.1.0'
$vision = 'torchvision[device-gfx1100]==0.29.0a0+rocm10.1.0'

# TripoSR pins old packages, so SDXL gets its own environment.
foreach ($venv in 'venv', 'venv-images') {
    if (-not (Test-Path "$Root\$venv\Scripts\python.exe")) { py -3.12 -m venv "$Root\$venv" }
}
$py3d = "$Root\venv\Scripts\python.exe"
$pyImages = "$Root\venv-images\Scripts\python.exe"

& $py3d -m pip install --index-url $amd $torch $vision
if ($LASTEXITCODE -ne 0) { throw 'PyTorch install failed for TripoSR' }
& $pyImages -m pip install --index-url $amd --extra-index-url https://pypi.org/simple $torch
if ($LASTEXITCODE -ne 0) { throw 'PyTorch install failed for SDXL' }
& $pyImages -m pip install diffusers transformers accelerate safetensors peft
if ($LASTEXITCODE -ne 0) { throw 'SDXL package install failed' }

if (-not (Test-Path "$Root\TripoSR")) { git clone https://github.com/VAST-AI-Research/TripoSR.git "$Root\TripoSR" }
# The commit the pipeline was tested on.
git -C "$Root\TripoSR" checkout 107cefdc244c39106fa830359024f6a2f1c78871

# torchmcubes doesn't build here, so the stand-in replaces it.
Get-Content "$Root\TripoSR\requirements.txt" | Where-Object { $_ -notmatch 'torchmcubes' } | Set-Content "$Root\requirements_no_mcubes.txt"
& $py3d -m pip install -r "$Root\requirements_no_mcubes.txt" onnxruntime
if ($LASTEXITCODE -ne 0) { throw 'TripoSR package install failed' }
Copy-Item "$Root\torchmcubes.py" "$Root\venv\Lib\site-packages\torchmcubes.py" -Force

# TripoSR's texture baking mixes CPU and GPU tensors.
$bake = "$Root\TripoSR\tsr\bake_texture.py"
$text = Get-Content $bake -Raw
$text = $text.Replace(
    'positions = torch.tensor(positions_texture.reshape(-1, 4)[:, :-1])',
    'positions = torch.tensor(positions_texture.reshape(-1, 4)[:, :-1]).to(scene_code.device)')
$text = $text.Replace('queried_grid["color"].numpy()', 'queried_grid["color"].cpu().numpy()')
Set-Content $bake $text -NoNewline

& $py3d -c "import torch; print('TripoSR GPU:', torch.cuda.is_available())"
& $pyImages -c "import torch; print('SDXL GPU:', torch.cuda.is_available())"
