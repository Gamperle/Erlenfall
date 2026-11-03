# Cleans a batch's models into <batch>\cleaned. Finished models are skipped.
# Only the names in <batch>\keep.txt are cleaned if that file exists. Face budgets and "long" come from batches\<batch>.json.
param(
    [Parameter(Mandatory)][string]$Batch,
    [string]$Root = 'D:\erlenfall-assets',
    [string]$Blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
)

$base = "$Root\$Batch"
$objects = (Get-Content "$Root\batches\$Batch.json" -Raw | ConvertFrom-Json).objects
$keep = if (Test-Path "$base\keep.txt") { @(Get-Content "$base\keep.txt" | Where-Object { $_.Trim() }) } else { @() }
$out = "$base\cleaned"
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($dir in Get-ChildItem "$base\models" -Directory | Sort-Object Name) {
    $name = $dir.Name
    if ($keep.Count -and $keep -notcontains $name) { continue }
    if (Test-Path "$out\$name.glb") { continue }
    $item = $objects.($name -replace '_\d+$', '')
    $mode = if ($item.mode) { $item.mode } else { 'upright' }
    $log = "$out\$name.log"
    cmd /c "`"$Blender`" -b -P $Root\cleanup_mesh.py -- $($dir.FullName)\0\mesh.obj $($dir.FullName)\0\texture.png $out\$name $($item.faces) $mode > $log 2>&1"
    $result = Select-String -Path $log -Pattern 'RESULT|Error|Traceback' | Select-Object -First 3 | ForEach-Object { $_.Line }
    "$name $($result -join ' | ')"
}
"finished"
