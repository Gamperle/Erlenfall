# Writes a batch's cleaned models at real size to <batch>\props, ready for assets/props.
# Sizes are each object's largest dimension in meters, from batches\<batch>.json.
param(
    [Parameter(Mandatory)][string]$Batch,
    [string]$Root = 'D:\erlenfall-assets',
    [string]$Blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
)

$base = "$Root\$Batch"
$objects = (Get-Content "$Root\batches\$Batch.json" -Raw | ConvertFrom-Json).objects
$out = "$base\props"
New-Item -ItemType Directory -Force $out, "$Root\tmp" | Out-Null
foreach ($file in Get-ChildItem "$base\cleaned\*.glb" | Sort-Object Name) {
    $name = $file.BaseName
    $meters = $objects.($name -replace '_\d+$', '').meters
    cmd /c "`"$Blender`" -b -P $Root\size_glb.py -- $($file.FullName) $out\$name.glb $meters > $Root\tmp\size.log 2>&1"
    "$name $((Select-String -Path "$Root\tmp\size.log" -Pattern 'RESULT|Error' | Select-Object -First 1).Line)"
}
"finished"
