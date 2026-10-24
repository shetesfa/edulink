$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127\.' -and $_.IPAddress -notmatch '^169\.' }
foreach ($a in $adapters) {
    Write-Host "Interface: $($a.InterfaceAlias) | IP: $($a.IPAddress)"
}
