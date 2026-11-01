# Stops a TripoSR run that has used no CPU for 5 minutes, so make_models retries it. Exits once no run has been seen for 10 minutes.
$idle = @{}
$quiet = 0
while ($quiet -lt 10) {
    $runs = @(Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.WorkingSet64 -gt 200MB })
    if ($runs.Count -eq 0) { $quiet++ } else { $quiet = 0 }
    foreach ($p in $runs) {
        $cpu = $p.TotalProcessorTime.TotalSeconds
        if ($idle.ContainsKey($p.Id) -and $idle[$p.Id].cpu -eq $cpu) {
            $idle[$p.Id].minutes++
            if ($idle[$p.Id].minutes -ge 5) {
                "$((Get-Date).ToString('HH:mm:ss')) stopped hung run $($p.Id)"
                Stop-Process -Id $p.Id -Force
            }
        } else {
            $idle[$p.Id] = @{ cpu = $cpu; minutes = 0 }
        }
    }
    Start-Sleep 60
}
"watchdog finished"
