# Runs the three mask scripts over <Run>\input and writes <Run>\masks\u2net, birefnet and ben2.
# Usage: run_masks.ps1 -Run D:\erlenfall-assets\bgcompare494 [-Which all|u2net|ben2|birefnet]
# The BEN2 venv and weights stay in bgcompare218 (see docs/ASSET_PIPELINE.md); the scripts are the ones in this folder.
param([Parameter(Mandatory)][string]$Run, [string]$Which = 'all')
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ben2 = 'D:\erlenfall-assets\bgcompare218\venv-ben2\Scripts\python.exe'
$env:TEMP = "$Run\tmp"; New-Item -ItemType Directory -Force $env:TEMP, "$Run\logs", "$Run\masks" | Out-Null; $env:TMP = $env:TEMP
if ($Which -in 'all', 'u2net') {
    "== u2net"
    & D:\erlenfall-assets\venv\Scripts\python.exe $here\mask_u2net.py $Run\input $Run\masks\u2net 2>&1 | Select-Object -Last 3
}
if ($Which -in 'all', 'ben2') {
    "== ben2"
    & $ben2 $here\mask_ben2.py $Run\input $Run\masks\ben2 2>&1 | Select-Object -Last 3
}
if ($Which -in 'all', 'birefnet') {
    "== birefnet"
    $py = 'D:\erlenfall-assets\venv-comfy\Scripts\python.exe'
    $before = @(Get-Process python -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $server = Start-Process $py -ArgumentList 'main.py', '--listen', '127.0.0.1', '--port', '8188', '--disable-auto-launch' -WorkingDirectory 'D:\erlenfall-assets\comfyui' -RedirectStandardOutput "$Run\logs\comfy.log" -RedirectStandardError "$Run\logs\comfy_errors.log" -NoNewWindow -PassThru
    $ready = $false
    for ($i = 0; $i -lt 60 -and -not $ready; $i++) { Start-Sleep 5; try { Invoke-RestMethod http://127.0.0.1:8188/system_stats | Out-Null; $ready = $true } catch { } }
    if ($ready) { & $py $here\mask_birefnet.py $Run\input $Run\masks\birefnet } else { 'ComfyUI did not start' }
    Get-Process python -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id } | Stop-Process -Force
}
