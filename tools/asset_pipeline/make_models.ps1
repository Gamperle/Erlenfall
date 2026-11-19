# Turns every picture in <batch>\input into a textured model and preview renders.
# run_triposr.py adds a "mesh" stage to <batch>\provenance\<name>.json (copy provenance.py next to it).
# Finished models are skipped, so it can safely be run again. See docs/ASSET_PIPELINE.md.
# The foreground masks come from BiRefNet (make_masks.py, through ComfyUI, which this script starts and stops), as TRELLIS.2's do (#492).
# -Mask u2net lets TripoSR's own rembg make them instead, which fills the gaps between thin parts such as spokes.
param(
    [Parameter(Mandatory)][string]$Batch,
    [ValidateSet('birefnet', 'u2net')][string]$Mask = 'birefnet',
    [string]$Root = 'D:\erlenfall-assets',
    [string]$Blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
)

$base = "$Root\$Batch"
$env:TEMP = "$Root\tmp"
$env:TMP = $env:TEMP
$env:HF_HOME = "$Root\hf-cache"
$env:U2NET_HOME = "$Root\u2net"
$py = "$Root\venv\Scripts\python.exe"
New-Item -ItemType Directory -Force "$base\models", "$base\previews", "$base\logs", "$base\provenance" | Out-Null

if ($Mask -eq 'birefnet') {
    $comfyPy = "$Root\venv-comfy\Scripts\python.exe"
    $before = @(Get-Process python -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $server = Start-Process $comfyPy -ArgumentList 'main.py', '--listen', '127.0.0.1', '--port', '8188', '--disable-auto-launch' `
        -WorkingDirectory "$Root\comfyui" -RedirectStandardOutput "$base\comfy.log" -RedirectStandardError "$base\comfy_errors.log" -NoNewWindow -PassThru
    $ready = $false
    for ($i = 0; $i -lt 60 -and -not $ready; $i++) {
        Start-Sleep 5
        try { Invoke-RestMethod http://127.0.0.1:8188/system_stats | Out-Null; $ready = $true } catch { }
    }
    if ($ready) { & $comfyPy "$Root\make_masks.py" $Batch } else { "ComfyUI did not start, see $base\comfy_errors.log" }
    # As in run_trellis.ps1: stop every Python process that started after this point.
    Get-Process python -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id } | Stop-Process -Force
}

Set-Location "$Root\TripoSR"
foreach ($image in Get-ChildItem "$base\input\*.png" | Sort-Object Name) {
    $name = $image.BaseName
    $out = "$base\models\$name"
    $attempt = 0
    # Runs sometimes crash at startup (issue #59), and retrying has worked.
    while (-not (Test-Path "$out\0\mesh.obj") -and $attempt -lt 8) {
        $attempt++
        # Each attempt keeps its own log, numbered across reruns, so a crash's stack trace survives the retry.
        $number = (Get-ChildItem "$base\logs\$name.attempt*.log" -ErrorAction SilentlyContinue | Measure-Object).Count + 1
        $log = "$base\logs\$name.attempt$number.log"
        $maskFile = "$base\masks\$name.png"
        if ($Mask -eq 'birefnet' -and -not (Test-Path $maskFile)) { "$name has no BiRefNet mask, see the mask step above"; break }
        $maskArgs = if ($Mask -eq 'birefnet') { "--mask $maskFile" } else { '' }
        cmd /c "`"$py`" $Root\run_triposr.py $($image.FullName) $maskArgs --output-dir $out --mc-resolution 256 --bake-texture > $log 2>&1"
        "exit code: $LASTEXITCODE" | Add-Content $log
    }
    if (Test-Path "$out\0\mesh.obj") {
        $stats = (& $py "$Root\check_mesh.py" "$out\0\mesh.obj" 2>&1 | Select-Object -First 1)
        if (-not (Test-Path "$base\previews\${name}_back.png")) {
            cmd /c "`"$Blender`" -b -P $Root\render_preview.py -- $out\0\mesh.obj $out\0\texture.png $base\previews\$name > $base\logs\${name}_render.log 2>&1"
        }
        "$name ok attempts=$attempt $stats"
    } else { "$name FAILED after $attempt attempts" }
}
"finished"
