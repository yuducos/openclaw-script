```powershell
# OpenClaw Gateway Deploy Script
# PowerShell shortcuts + Autostart
# Usage: irm URL | iex

$ErrorActionPreference = "Stop"

Write-Host "OpenClaw Gateway Deploy" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan

$dir = "$env:USERPROFILE\.openclaw\workspace"
New-Item -Path $dir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# Step 1: Create gateway-simple.ps1
Write-Host "`n[1/5] Creating gateway-simple.ps1..." -ForegroundColor Yellow

$gatewayLines = @(
    '# OpenClaw Gateway Control Functions'
    '# Commands: ogstart, ogstop, ogrestart, ogstatus, ogenable, ogdisable'
    ''
    'function Start-OG {'
    '    param([switch]$ShowWindow)'
    '    $existing = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*openclaw*" }'
    '    if ($existing) {'
    '        Write-Host "Gateway already running (PID: $($existing.Id))" -ForegroundColor Yellow'
    '        return'
    '    }'
    '    $ws = if ($ShowWindow) { "Normal" } else { "Hidden" }'
    '    Start-Process -FilePath "$env:APPDATA\npm\openclaw.cmd" -ArgumentList "gateway","run","--compact" -WindowStyle $ws -WorkingDirectory "$env:USERPROFILE"'
    '    Write-Host "Gateway started" -ForegroundColor Green'
    '    Start-Sleep -Seconds 2'
    '    openclaw gateway status'
    '}'
    ''
    'function Stop-OG {'
    '    openclaw gateway stop'
    '    Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*openclaw*" } | Stop-Process -Force'
    '    Write-Host "Gateway stopped" -ForegroundColor Green'
    '}'
    ''
    'function Restart-OG {'
    '    Stop-OG'
    '    Start-Sleep -Seconds 2'
    '    Start-OG'
    '}'
    ''
    'function Status-OG {'
    '    openclaw gateway status'
    '}'
    ''
    'function Enable-OGAutostart {'
    '    $tn = "OpenClaw Gateway"'
    '    $ex = schtasks /Query /TN $tn 2>&1 | Out-String'
    '    if ($ex -notlike "*error*" -and $ex -notlike "*ERROR*" -and $ex -notlike "*错误*") {'
    '        Write-Host "Autostart already exists" -ForegroundColor Yellow'
    '        return'
    '    }'
    '    schtasks /Create /TN $tn /TR "powershell.exe -WindowStyle Hidden -Command Start-Process -FilePath ''%APPDATA%\npm\openclaw.cmd'' -ArgumentList ''gateway'',''run'',''--compact'' -WindowStyle Hidden" /SC ONLOGON /DELAY 0000:30 /RL HIGHEST /F | Out-Null'
    '    Write-Host "Autostart enabled" -ForegroundColor Green'
    '}'
    ''
    'function Disable-OGAutostart {'
    '    schtasks /Delete /TN "OpenClaw Gateway" /F 2>&1 | Out-Null'
    '    Write-Host "Autostart disabled" -ForegroundColor Green'
    '}'
    ''
    'Set-Alias ogstart Start-OG'
    'Set-Alias ogstop Stop-OG'
    'Set-Alias ogrestart Restart-OG'
    'Set-Alias ogstatus Status-OG'
    'Set-Alias ogenable Enable-OGAutostart'
    'Set-Alias ogdisable Disable-OGAutostart'
    ''
    'Write-Host "Commands loaded: ogstart, ogstop, ogrestart, ogstatus, ogenable, ogdisable" -ForegroundColor DarkGray'
)

Set-Content -Path "$dir\gateway-simple.ps1" -Value ($gatewayLines -join "`r`n") -Encoding UTF8
Write-Host "  OK: $dir\gateway-simple.ps1" -ForegroundColor Green

# Step 2: WinPS5 Profile
Write-Host "`n[2/5] Configuring Windows PowerShell 5..." -ForegroundColor Yellow
$wpDir = "$env:USERPROFILE\Documents\WindowsPowerShell"
New-Item -Path $wpDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
$wpProfile = '$g="$env:USERPROFILE\.openclaw\workspace\gateway-simple.ps1"' + "`r`n" + 'if(Test-Path $g){. $g}'
Set-Content -Path "$wpDir\Microsoft.PowerShell_profile.ps1" -Value $wpProfile -Encoding UTF8
Write-Host "  OK: WinPS5 Profile" -ForegroundColor Green

# Step 3: PS7 Profile  
Write-Host "`n[3/5] Configuring PowerShell 7..." -ForegroundColor Yellow
$ps7Dir = "$env:USERPROFILE\Documents\PowerShell"
New-Item -Path $ps7Dir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
$ps7Profile = '$w="$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"' + "`r`n" + 'if(Test-Path $w){. $w}'
Set-Content -Path "$ps7Dir\Microsoft.PowerShell_profile.ps1" -Value $ps7Profile -Encoding UTF8
Write-Host "  OK: PS7 Profile" -ForegroundColor Green

# Step 4: Autostart Task
Write-Host "`n[4/5] Creating autostart task..." -ForegroundColor Yellow
$taskCheck = schtasks /Query /TN "OpenClaw Gateway" 2>&1 | Out-String
if ($taskCheck -like "*error*" -or $taskCheck -like "*ERROR*" -or $taskCheck -like "*错误*") {
    schtasks /Create /TN "OpenClaw Gateway" /TR "powershell.exe -WindowStyle Hidden -Command Start-Process -FilePath '%APPDATA%\npm\openclaw.cmd' -ArgumentList 'gateway','run','--compact' -WindowStyle Hidden" /SC ONLOGON /DELAY 0000:30 /RL HIGHEST /F | Out-Null
    Write-Host "  OK: Autostart task created (30s delay)" -ForegroundColor Green
} else {
    Write-Host "  SKIP: Task already exists" -ForegroundColor Yellow
}

# Step 5: Batch file
Write-Host "`n[5/5] Creating start-gateway.bat..." -ForegroundColor Yellow
$batLines = @(
    '@echo off'
    'chcp 65001 >nul'
    'title OpenClaw Gateway'
    'tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe">NUL'
    'if "%ERRORLEVEL%"=="0" ('
    '    echo Gateway already running'
    '    openclaw gateway status'
    '    pause'
    '    exit /b'
    ')'
    'echo Starting Gateway...'
    'powershell -WindowStyle Hidden -Command "Start-Process -FilePath ''%APPDATA%\npm\openclaw.cmd'' -ArgumentList ''gateway'',''run'',''--compact'' -WindowStyle Hidden -WorkingDirectory ''%USERPROFILE%''"'
    'timeout /t 2 /nobreak >nul'
    'echo Started'
    'openclaw gateway status'
    'pause'
)
Set-Content -Path "$dir\start-gateway.bat" -Value ($batLines -join "`r`n") -Encoding UTF8
Write-Host "  OK: $dir\start-gateway.bat" -ForegroundColor Green

# Done
Write-Host "`n=======================" -ForegroundColor Cyan
Write-Host "Done!" -ForegroundColor Green
Write-Host "`nCommands:" -ForegroundColor Cyan
Write-Host "  ogstart    - Start Gateway (background)"
Write-Host "  ogstop     - Stop Gateway"
Write-Host "  ogrestart  - Restart Gateway"
Write-Host "  ogstatus   - Check status"
Write-Host "  ogenable   - Enable autostart"
Write-Host "  ogdisable  - Disable autostart"
Write-Host "`nRestart PowerShell to use commands" -ForegroundColor DarkGray
```

---

### 关键改进

| 问题 | 解决方式 |
|------|---------|
| here-string 解析错误 | 改用 `@()` 数组 + `-join "`r`n"` |
| 缺少步骤说明 | 保留 `[1/5]` 到 `[5/5]` 进度 |
| 缺少 6 个命令 | 完整保留 ogstart/ogstop/ogrestart/ogstatus/ogenable/ogdisable |

粘贴后 **Commit**，然后测试：
```powershell
irm "https://raw.githubusercontent.com/yuducos/openclaw-script/main/deploy-gateway-full.ps1" | iex
```
