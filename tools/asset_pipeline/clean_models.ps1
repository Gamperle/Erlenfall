# Cleans the models in <Root>\selected into <Root>\cleaned. Finished models are skipped.
param(
    [string]$Root = 'D:\erlenfall-assets',
    [string]$Only = '',
    [string]$Blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
)

# Face budgets for each type. Starting points to test against integrated graphics.
$budgets = @{
    anvil = 3000; barrel = 2500; bowl = 1200; cauldron = 3000; chest = 4000; cupboard = 6000; desk = 6000; door = 5000
    forge = 8000; hammer = 1500; jug = 1500; kiln = 6000; lantern = 3000; pan = 1200; stone_wall = 6000; stool = 2000
    sword = 1200; short_sword = 1200
}
$long = 'sword', 'short_sword'

$out = "$Root\cleaned"
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($dir in Get-ChildItem "$Root\selected" -Directory | Sort-Object Name) {
    $name = $dir.Name
    if ($Only -and ($Only -split ',') -notcontains $name) { continue }
    if (Test-Path "$out\$name.glb") { continue }
    $type = $name -replace '_\d+$', ''
    $mode = if ($long -contains $type) { 'long' } else { 'upright' }
    $log = "$out\$name.log"
    cmd /c "`"$Blender`" -b -P $Root\cleanup_mesh.py -- $($dir.FullName)\mesh.obj $($dir.FullName)\texture.png $out\$name $($budgets[$type]) $mode > $log 2>&1"
    $result = Select-String -Path $log -Pattern 'RESULT|Error|Traceback' | Select-Object -First 3 | ForEach-Object { $_.Line }
    "$name $($result -join ' | ')"
}
"finished"
