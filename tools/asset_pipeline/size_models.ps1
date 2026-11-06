# Writes a batch's models at real size to <batch>\props, ready for assets/props. -Source picks the folder:
# trellis for TRELLIS.2 models, or cleaned for cleaned TripoSR models.
# Sizes are each object's largest dimension in meters, from batches\<batch>.json. A TRELLIS.2 model that
# doesn't face the front can be turned by listing it under "turns" there, in degrees.
param(
    [Parameter(Mandatory)][string]$Batch,
    [string]$Source = 'trellis',
    [string]$Root = 'D:\erlenfall-assets',
    [string]$Blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
)

$base = "$Root\$Batch"
$config = Get-Content "$Root\batches\$Batch.json" -Raw | ConvertFrom-Json
$out = "$base\props"
New-Item -ItemType Directory -Force $out, "$Root\tmp" | Out-Null
foreach ($file in Get-ChildItem "$base\$Source\*.glb" | Sort-Object Name) {
    $name = $file.BaseName
    $meters = $config.objects.($name -replace '_\d+$', '').meters
    # TripoSR models face +X and need a quarter turn. TRELLIS.2 models usually face the front already.
    $turn = if ($Source -eq 'cleaned') { -90 } elseif ($config.turns.$name -ne $null) { $config.turns.$name } else { 0 }
    cmd /c "`"$Blender`" -b -P $Root\size_glb.py -- $($file.FullName) $out\$name.glb $meters $turn > $Root\tmp\size.log 2>&1"
    "$name $((Select-String -Path "$Root\tmp\size.log" -Pattern 'SIZED|Error:|Traceback' -CaseSensitive | Select-Object -First 1).Line)"
}
"finished"
