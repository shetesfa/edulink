param([string]$NewIP)

$backendEnv = 'e:\EduLink-Complete\backend\.env'
$flutterEnv = 'e:\EduLink-Complete\flutter_app\.env'

# Update backend .env
if (Test-Path $backendEnv) {
    $c = [System.IO.File]::ReadAllText($backendEnv)
    $c = $c -replace 'APP_URL=http://[^\r\n]+', "APP_URL=http://$($NewIP):8000"
    $c = $c -replace 'REVERB_HOST=[^\r\n]+', "REVERB_HOST=$NewIP"
    $c = $c -replace 'VITE_REVERB_HOST=[^\r\n]+', "VITE_REVERB_HOST=$NewIP"
    $c = $c -replace 'SANCTUM_STATEFUL_DOMAINS=[^\r\n]+', "SANCTUM_STATEFUL_DOMAINS=localhost,127.0.0.1,$NewIP"
    $c = $c -replace 'FRONTEND_URL=http://[^\r\n]+', "FRONTEND_URL=http://$($NewIP):3000"
    [System.IO.File]::WriteAllText($backendEnv, $c)
    Write-Host "  [OK] Backend .env updated -> IP: $NewIP"
}

# Update flutter .env
$fc  = "# Auto-updated by START_SERVER.bat`r`n"
$fc += "API_BASE_URL=http://$($NewIP):8000/api`r`n"
$fc += "`r`n"
$fc += "REVERB_HOST=$NewIP`r`n"
$fc += "REVERB_PORT=8080`r`n"
$fc += "REVERB_APP_KEY=edulink-local-2026-4cd7a08f`r`n"
$fc += "REVERB_USE_TLS=false`r`n"
[System.IO.File]::WriteAllText($flutterEnv, $fc)
Write-Host "  [OK] Flutter .env updated -> IP: $NewIP"
