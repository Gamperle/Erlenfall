# Writes a batch's models at real size to <batch>\props, ready for assets/props. -Source picks the folder:
# trellis for TRELLIS.2 models, trellis_s<seed> for a variant made with TRELLIS_SEED, or cleaned for cleaned TripoSR models.
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
# A variant (make_trellis.py with TRELLIS_SEED or TRELLIS_PIXAL3D) is sized into its own folders, so the usual models stay.
$variant = if ($Source -like 'trellis*') { $Source -replace '^trellis', '' } else { '' }
$out = "$base\props$variant"
New-Item -ItemType Directory -Force $out, "$Root\tmp" | Out-Null
foreach ($file in Get-ChildItem "$base\$Source\*.glb" | Sort-Object Name) {
    $name = $file.BaseName
    $meters = $config.objects.($name -replace '_\d+$', '').meters
    # TripoSR models face +X and need a quarter turn. TRELLIS.2 models usually face the front already.
    $turn = if ($Source -eq 'cleaned') { -90 } elseif ($config.turns.$name -ne $null) { $config.turns.$name } else { 0 }
    cmd /c "`"$Blender`" -b -P $Root\size_glb.py -- $($file.FullName) $out\$name.glb $meters $turn $base\provenance$variant > $Root\tmp\size.log 2>&1"
    "$name $((Select-String -Path "$Root\tmp\size.log" -Pattern 'SIZED|Error:|Traceback' -CaseSensitive | Select-Object -First 1).Line)"
}
# Shrink the textures to the prop's size tier (#445): 512 px up to 1.25 m, else 1024 px. Needs the asset PC's
# Python with Pillow and numpy, and shrink_textures.py and provenance.py copied next to this script. Adds a
# "textures" stage to each model's record in $base\provenance, as size_glb.py does for its "size" stage.
$shrink = "$Root\shrink_textures.py"
if (Test-Path $shrink) {
    python $shrink --apply --provenance "$base\provenance" (Get-ChildItem "$out\*.glb" | ForEach-Object FullName)
} else {
    "shrink_textures.py not found in ${Root}: textures stay at 1024 px (copy it, see the README)"
}
"finished"
