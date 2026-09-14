$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$binary = Join-Path $projectRoot 'bin\icloud-privacy-mail.exe'
$configPath = Join-Path $projectRoot 'config.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$existing = Get-CimInstance Win32_Process -Filter "Name = 'icloud-privacy-mail.exe'" | Where-Object { $_.ExecutablePath -eq $binary }
if (-not $existing) {
    $logs = Join-Path $projectRoot 'logs'
    New-Item -ItemType Directory -Path $logs -Force | Out-Null
    $process = Start-Process -FilePath $binary -ArgumentList @('--config', ('"' + $configPath + '"')) -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logs 'panel.stdout.log') -RedirectStandardError (Join-Path $logs 'panel.stderr.log') -PassThru
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        if ($process.HasExited) { throw 'Service exited; inspect logs\panel.stderr.log and logs\panel.stdout.log.' }
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$($config.port)/login" -TimeoutSec 2
            if ($response.StatusCode -eq 200) { break }
        } catch { Start-Sleep -Milliseconds 300 }
    }
}
$response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$($config.port)/login" -TimeoutSec 5
if ($response.StatusCode -ne 200) { throw 'Login page check failed.' }
Write-Output "RUNNING http://127.0.0.1:$($config.port)/login"
