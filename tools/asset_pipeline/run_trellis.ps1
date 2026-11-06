# Starts ComfyUI, turns a batch's pictures into TRELLIS.2 models with make_trellis.py, then stops ComfyUI.
# Extra names after the batch limit it to those pictures. See tools/asset_pipeline/README.md.
param(
    [Parameter(Mandatory)][string]$Batch,
    [string[]]$Names = @(),
    [string]$Root = 'D:\erlenfall-assets'
)

$env:TEMP = "$Root\tmp"
$env:TMP = $env:TEMP
$py = "$Root\venv-comfy\Scripts\python.exe"
$before = @(Get-Process python -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
# ComfyUI listens only on this PC. Reach it from elsewhere through an SSH tunnel to port 8188.
$server = Start-Process $py -ArgumentList 'main.py', '--listen', '127.0.0.1', '--port', '8188', '--disable-auto-launch' `
    -WorkingDirectory "$Root\comfyui" -RedirectStandardOutput "$Root\$Batch\comfy.log" -RedirectStandardError "$Root\$Batch\comfy_errors.log" `
    -NoNewWindow -PassThru
$ready = $false
for ($i = 0; $i -lt 60 -and -not $ready; $i++) {
    Start-Sleep 5
    try { Invoke-RestMethod http://127.0.0.1:8188/system_stats | Out-Null; $ready = $true } catch { }
}
if ($ready) { & $py "$Root\make_trellis.py" $Batch @Names } else { "ComfyUI did not start, see $Root\$Batch\comfy_errors.log" }
# The venv's python.exe starts the real interpreter as a child. Without administrator rights the child
# can't be found through its parent, so stop every Python process that started after this script.
Get-Process python -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id } | Stop-Process -Force
