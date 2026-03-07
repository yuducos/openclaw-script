# OpenClaw Gateway 完整部署脚本
# 功能：PowerShell 快捷命令 + 开机无窗口自启
# 在目标机器上以普通用户身份运行（无需管理员）

$ErrorActionPreference = "Stop"

Write-Host "🦞 OpenClaw Gateway 完整部署" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "包含：快捷命令 + 开机自启（无窗口）" -ForegroundColor DarkGray

# ========== 步骤 1: 创建 Gateway 功能脚本 ==========
$gatewayScriptPath = "$env:USERPROFILE\.openclaw\workspace\gateway-simple.ps1"
$gatewayScriptDir = Split-Path $gatewayScriptPath -Parent

Write-Host "`n[1/5] 创建功能脚本..." -ForegroundColor Yellow

if (!(Test-Path $gatewayScriptDir)) {
    New-Item -Path $gatewayScriptDir -ItemType Directory -Force | Out-Null
    Write-Host "  ✓ 工作目录: $gatewayScriptDir"
}

$gatewayScriptContent = @'
# OpenClaw Gateway Control Functions
# 用法: ogstart, ogstop, ogrestart, ogstatus, ogenable, ogdisable

function Start-OG {
    param([switch]$ShowWindow)
    $existing = Get-Process -Name "node" -ErrorAction SilentlyContinue | 
        Where-Object { $_.CommandLine -like "*openclaw*" }
    if ($existing) {
        Write-Host "⚡ Gateway already running (PID: $($existing.Id))" -ForegroundColor Yellow
        return
    }
    $windowStyle = if ($ShowWindow) { "Normal" } else { "Hidden" }
    Start-Process -FilePath "$env:APPDATA\npm\openclaw.cmd" `
        -ArgumentList "gateway","run","--compact" `
        -WindowStyle $windowStyle `
        -WorkingDirectory "$env:USERPROFILE"
    Write-Host "✅ Gateway started" -ForegroundColor Green
    Start-Sleep -Seconds 1
    openclaw gateway status
}

function Stop-OG {
    openclaw gateway stop
    # 确保 node 进程也被终止
    Get-Process -Name "node" -ErrorAction SilentlyContinue | 
        Where-Object { $_.CommandLine -like "*openclaw*" } | 
        Stop-Process -Force
    Write-Host "✅ Gateway stopped" -ForegroundColor Green
}

function Restart-OG {
    Stop-OG
    Start-Sleep -Seconds 2
    Start-OG
}

function Status-OG {
    openclaw gateway status
}

function Enable-OGAutostart {
    $taskName = "OpenClaw Gateway"
    $taskExists = schtasks /Query /TN $taskName 2>&1 | Out-String
    if ($taskExists -notlike "*错误*") {
        Write-Host "⚡ 开机自启已存在" -ForegroundColor Yellow
        return
    }
    schtasks /Create /TN $taskName /TR "powershell.exe -WindowStyle Hidden -Command Start-Process -FilePath '%APPDATA%\npm\openclaw.cmd' -ArgumentList 'gateway','run','--compact' -WindowStyle Hidden" /SC ONLOGON /DELAY 0000:30 /RL HIGHEST /F | Out-Null
    Write-Host "✅ 开机自启已启用" -ForegroundColor Green
}

function Disable-OGAutostart {
    $taskName = "OpenClaw Gateway"
    schtasks /Delete /TN $taskName /F 2>&1 | Out-Null
    Write-Host "✅ 开机自启已禁用" -ForegroundColor Green
}

Set-Alias -Name ogstart -Value Start-OG
Set-Alias -Name ogstop -Value Stop-OG
Set-Alias -Name ogrestart -Value Restart-OG
Set-Alias -Name ogstatus -Value Status-OG
Set-Alias -Name ogenable -Value Enable-OGAutostart
Set-Alias -Name ogdisable -Value Disable-OGAutostart

Write-Host "Commands: ogstart, ogstop, ogrestart, ogstatus, ogenable, ogdisable" -ForegroundColor DarkGray
'@

Set-Content -Path $gatewayScriptPath -Value $gatewayScriptContent -Encoding UTF8
Write-Host "  ✓ 功能脚本: $gatewayScriptPath"

# ========== 步骤 2: 配置 Windows PowerShell 5 Profile ==========
Write-Host "`n[2/5] 配置 Windows PowerShell 5..." -ForegroundColor Yellow

$winPSProfile = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$winPSDir = Split-Path $winPSProfile -Parent

if (!(Test-Path $winPSDir)) {
    New-Item -Path $winPSDir -ItemType Directory -Force | Out-Null
}

$winProfileContent = @'
# OpenClaw Gateway shortcut commands
$gatewayScript = "$env:USERPROFILE\.openclaw\workspace\gateway-simple.ps1"
if (Test-Path $gatewayScript) {
    . $gatewayScript
}
'@

Set-Content -Path $winPSProfile -Value $winProfileContent -Encoding UTF8
Write-Host "  ✓ Profile: $winPSProfile"

# ========== 步骤 3: 配置 PowerShell 7 Profile ==========
Write-Host "`n[3/5] 配置 PowerShell 7..." -ForegroundColor Yellow

$ps7Profile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
$ps7Dir = Split-Path $ps7Profile -Parent

if (!(Test-Path $ps7Dir)) {
    New-Item -Path $ps7Dir -ItemType Directory -Force | Out-Null
}

$ps7ProfileContent = @'
# Load Windows PowerShell profile for compatibility
$winPSProfile = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $winPSProfile) {
    . $winPSProfile
}
'@

Set-Content -Path $ps7Profile -Value $ps7ProfileContent -Encoding UTF8
Write-Host "  ✓ Profile: $ps7Profile"

# ========== 步骤 4: 创建开机自启任务 ==========
Write-Host "`n[4/5] 配置开机自启（无窗口）..." -ForegroundColor Yellow

$taskName = "OpenClaw Gateway"
$taskExists = schtasks /Query /TN $taskName 2>&1 | Out-String

if ($taskExists -like "*错误*" -or $taskExists -like "*ERROR*") {
    schtasks /Create /TN $taskName `
        /TR "powershell.exe -WindowStyle Hidden -Command Start-Process -FilePath '%APPDATA%\npm\openclaw.cmd' -ArgumentList 'gateway','run','--compact' -WindowStyle Hidden" `
        /SC ONLOGON `
        /DELAY 0000:30 `
        /RL HIGHEST `
        /F | Out-Null
    Write-Host "  ✓ 开机自启任务已创建（延迟30秒启动）"
} else {
    Write-Host "  ⚡ 开机自启任务已存在，跳过"
}

# ========== 步骤 5: 创建双击启动脚本 ==========
Write-Host "`n[5/5] 创建桌面快捷方式..." -ForegroundColor Yellow

$batContent = @'@echo off
chcp 65001 >nul
title OpenClaw Gateway

tasklist /FI "IMAGENAME eq node.exe" 2>NUL | find /I /N "node.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo ⚡ Gateway already running
    openclaw gateway status
    pause
    exit /b
)

echo Starting Gateway...
powershell -WindowStyle Hidden -Command "Start-Process -FilePath '%APPDATA%\npm\openclaw.cmd' -ArgumentList 'gateway','run','--compact' -WindowStyle Hidden -WorkingDirectory '%USERPROFILE%'"

timeout /t 2 /nobreak >nul
echo ✅ Started
openclaw gateway status
pause
'@

$batPath = "$env:USERPROFILE\.openclaw\workspace\start-gateway.bat"
Set-Content -Path $batPath -Value $batContent -Encoding UTF8
Write-Host "  ✓ 双击脚本: $batPath"

# ========== 完成 ==========
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "✅ 部署完成！" -ForegroundColor Green
Write-Host "`n📋 快捷命令（重新打开 PowerShell 后可用）：" -ForegroundColor Cyan
Write-Host "  ogstart     - 后台启动 Gateway（无窗口）" -ForegroundColor White
Write-Host "  ogstop      - 停止 Gateway" -ForegroundColor White
Write-Host "  ogrestart   - 重启 Gateway" -ForegroundColor White
Write-Host "  ogstatus    - 查看运行状态" -ForegroundColor White
Write-Host "  ogenable    - 启用开机自启" -ForegroundColor White
Write-Host "  ogdisable   - 禁用开机自启" -ForegroundColor White
Write-Host "`n🚀 开机行为：" -ForegroundColor Cyan
Write-Host "  登录后30秒自动启动（完全无窗口）" -ForegroundColor White
Write-Host "`n🖱️ 手动启动：" -ForegroundColor Cyan
Write-Host "  双击: $batPath" -ForegroundColor White
Write-Host "`n💡 提示：关闭所有 PowerShell 窗口后重新打开，即可使用快捷命令" -ForegroundColor DarkGray
