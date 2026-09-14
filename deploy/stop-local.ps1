$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$binary = Join-Path $projectRoot 'bin\icloud-privacy-mail.exe'
$processes = Get-CimInstance Win32_Process -Filter "Name = 'icloud-privacy-mail.exe'" | Where-Object { $_.ExecutablePath -eq $binary }
foreach ($process in $processes) {
    Stop-Process -Id $process.ProcessId -Force
    Wait-Process -Id $process.ProcessId -Timeout 10 -ErrorAction SilentlyContinue
}
Write-Output 'STOPPED; configuration and data retained.'
