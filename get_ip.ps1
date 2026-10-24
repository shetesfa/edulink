# get_ip.ps1 - Reliable IP detection using ipconfig output
# Works on all PowerShell versions, no regex module dependency

$lines = ipconfig | Select-String 'IPv4'
$ip = '127.0.0.1'

foreach ($l in $lines) {
    $candidate = $l.Line.Split(':')[-1].Trim()
    if ($candidate -notlike '127.*' -and $candidate -notlike '169.*') {
        $ip = $candidate
        break
    }
}

Write-Output $ip
