# Writes the chosen models at real size to <Root>\props. Sizes are each object's largest dimension in meters.
param([string]$Root = 'D:\erlenfall-assets')
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
$sizes = @{
    anvil = 0.8; barrel = 1.0; bowl = 0.25; cauldron = 0.55; chest = 0.9; cupboard = 1.6; desk = 1.2; door = 2.4
    forge = 2.5; hammer = 0.4; kiln = 1.8; lantern = 0.35; pan = 0.5; short_sword = 0.7; sword = 1.1; stone_wall = 2.0; stool = 0.45
}
$out = "$Root\props"
New-Item -ItemType Directory -Force $out | Out-Null
foreach ($file in Get-ChildItem "$Root\selected_klein\*.glb" | Sort-Object Name) {
    $name = $file.BaseName
    $type = $name -replace '_\d+$', ''
    cmd /c "`"$blender`" -b -P $Root\size_glb.py -- $($file.FullName) $out\$name.glb $($sizes[$type]) > $Root\tmp\size.log 2>&1"
    "$name $((Select-String -Path "$Root\tmp\size.log" -Pattern 'RESULT|Error' | Select-Object -First 1).Line)"
}
"finished"
