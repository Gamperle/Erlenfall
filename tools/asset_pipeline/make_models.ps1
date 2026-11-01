# Turns every picture in <batch>\input into a textured model and preview renders.
# Finished models are skipped, so it can safely be run again. See docs/ASSET_PIPELINE.md.
param(
    [Parameter(Mandatory)][string]$Batch,
    [string]$Root = 'D:\erlenfall-assets',
    [string]$Blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
)

$base = "$Root\$Batch"
$env:TEMP = "$Root\tmp"
$env:TMP = $env:TEMP
$env:HF_HOME = "$Root\hf-cache"
$env:U2NET_HOME = "$Root\u2net"
$py = "$Root\venv\Scripts\python.exe"
New-Item -ItemType Directory -Force "$base\models", "$base\previews", "$base\logs" | Out-Null

Set-Location "$Root\TripoSR"
foreach ($image in Get-ChildItem "$base\input\*.png" | Sort-Object Name) {
    $name = $image.BaseName
    $out = "$base\models\$name"
    $attempt = 0
    # Runs sometimes crash at startup (issue #59), and retrying has worked.
    while (-not (Test-Path "$out\0\mesh.obj") -and $attempt -lt 8) {
        $attempt++
        cmd /c "`"$py`" run.py $($image.FullName) --output-dir $out --mc-resolution 256 --bake-texture > $base\logs\$name.log 2>&1"
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
