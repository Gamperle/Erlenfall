# Installs ComfyUI with AMD's ROCm PyTorch and downloads the TRELLIS.2 models, for make_trellis.py.
# Needs Python 3.12 and Git, which setup_pc.ps1's administrator step installs. About 15 GB of models.
param([string]$Root = 'D:\erlenfall-assets')

Set-Location $Root
$env:PIP_CACHE_DIR = "$Root\pip-cache"
$env:TEMP = "$Root\tmp"
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force $env:TEMP | Out-Null
$log = "$Root\comfy_install.log"
if (-not (Test-Path "$Root\comfyui")) { git clone --quiet --branch v0.43.0 --depth 1 https://github.com/Comfy-Org/ComfyUI.git "$Root\comfyui" 2>&1 | Out-File $log }
$py = "$Root\venv-comfy\Scripts\python.exe"
if (-not (Test-Path $py)) { py -3.12 -m venv "$Root\venv-comfy" }
cmd /c "`"$py`" -m pip install --upgrade pip >> $log 2>&1"
cmd /c "`"$py`" -m pip install --index-url https://stable.repo.amd.com/rocm/whl-next/ --extra-index-url https://pypi.org/simple `"torch[device-gfx1100]==2.14.0+rocm10.1.0`" `"torchvision[device-gfx1100]==0.29.0a0+rocm10.1.0`" >> $log 2>&1"
"torch exit: $LASTEXITCODE"
# Torch is already the ROCm build, so ComfyUI's requirements must not replace it.
Get-Content "$Root\comfyui\requirements.txt" | Where-Object { $_ -notmatch '^(torch|torchvision|torchaudio)\s*$' } | Set-Content "$Root\tmp\comfy_req.txt"
cmd /c "`"$py`" -m pip install -r $Root\tmp\comfy_req.txt >> $log 2>&1"
"requirements exit: $LASTEXITCODE"
& $py -c "import torch; print('torch', torch.__version__, 'gpu', torch.cuda.is_available())"

# Comfy-Org's repackaged files, as the TRELLIS.2 workflow template lists them. Pixal3D and MoGe are only
# loaded because the template can switch to Pixal3D.
$models = "$Root\comfyui\models"
$files = @(
    @('vae', 'Comfy-Org/Pixal3D/resolve/main/vae/trellis_2_texture_vae_bf16.safetensors'),
    @('vae', 'Comfy-Org/Pixal3D/resolve/main/vae/trellis_2_shape_vae_bf16.safetensors'),
    @('clip_vision', 'Comfy-Org/Pixal3D/resolve/main/clip_vision/dino_v3_L_naf_fp32.safetensors'),
    @('geometry_estimation', 'Comfy-Org/MoGe/resolve/main/geometry_estimation/moge_2_vitl_normal_fp16.safetensors'),
    @('background_removal', 'Comfy-Org/BiRefNet/resolve/main/background_removal/birefnet.safetensors'),
    @('diffusion_models', 'Comfy-Org/TRELLIS.2/resolve/main/diffusion_models/trellis_2_int8_convrot.safetensors'),
    @('diffusion_models', 'Comfy-Org/Pixal3D/resolve/main/diffusion_models/pixal3d_int8_convrot.safetensors')
)
foreach ($f in $files) {
    $dir = "$models\$($f[0])"
    New-Item -ItemType Directory -Force $dir | Out-Null
    $target = "$dir\$(Split-Path $f[1] -Leaf)"
    if (Test-Path $target) { continue }
    curl.exe -sL --fail -o "$target.part" "https://huggingface.co/$($f[1])"
    if ($LASTEXITCODE -eq 0) { Move-Item "$target.part" $target; "got $(Split-Path $f[1] -Leaf)" } else { "FAILED $(Split-Path $f[1] -Leaf)" }
}
"finished"
