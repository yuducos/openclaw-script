```powershell
Write-Host 'OpenClaw Gateway Deploy' -ForegroundColor Cyan
$ErrorActionPreference='Stop'
$d="$env:USERPROFILE\.openclaw\workspace"
New-Item -Path $d -ItemType Directory -Force -EA SilentlyContinue

$f1="$d\gateway-simple.ps1"
'function Start-OG{param([switch]$s);$e=gps node -EA SilentlyContinue|?{$_.CommandLine-like"*openclaw*"};if($e){Write-Host "Already running (PID:$($e.Id))" -Fore Yellow;return};$w=if($s){"Normal"}else{"Hidden"};Start-Process "$env:APPDATA\npm\openclaw.cmd" -ArgumentList "gateway","run","--compact" -WindowStyle $w -WorkingDirectory $env:USERPROFILE;Write-Host "Started" -Fore Green;Start-Sleep 2;openclaw gateway status}'|Out-File $f1
'function Stop-OG{openclaw gateway stop;gps node -EA SilentlyContinue|?{$_.CommandLine-like"*openclaw*"}|Stop-Process -Force;Write-Host "Stopped" -Fore Green}'|Add-Content $f1
'function Restart-OG{Stop-OG;Start-Sleep 2;Start-OG}'|Add-Content $f1
'function Status-OG{openclaw gateway status}'|Add-Content $f1
'function Enable-OGAutostart{$tn="OpenClaw Gateway";$ex=schtasks /Query /TN $tn 2>&1|Out-String;if($ex-notlike "*error*"-and$ex-notlike "*ERROR*"){Write-Host "Exists" -Fore Yellow;return};schtasks /Create /TN $tn /TR "powershell.exe -WindowStyle Hidden -Command Start-Process -FilePath ''%APPDATA%\npm\openclaw.cmd'' -ArgumentList ''gateway'',''run'',''--compact'' -WindowStyle Hidden" /SC ONLOGON /DELAY 0000:30 /RL HIGHEST /F|Out-Null;Write-Host "Enabled" -Fore Green}'|Add-Content $f1
'function Disable-OGAutostart{schtasks /Delete /TN "OpenClaw Gateway" /F 2>&1|Out-Null;Write-Host "Disabled" -Fore Green}'|Add-Content $f1
'Set-Alias ogstart Start-OG;Set-Alias ogstop Stop-OG;Set-Alias ogrestart Restart-OG;Set-Alias ogstatus Status-OG;Set-Alias ogenable Enable-OGAutostart;Set-Alias ogdisable Disable-OGAutostart'|Add-Content $f1
'Write-Host "Commands: ogstart,ogstop,ogrestart,ogstatus,ogenable,ogdisable" -Fore DarkGray'|Add-Content $f1
Write-Host "Created gateway-simple.ps1" -Fore Green

$p="$env:USERPROFILE\Documents\WindowsPowerShell"
New-Item -Path $p -ItemType Directory -Force -EA SilentlyContinue
'$f="$env:USERPROFILE\.openclaw\workspace\gateway-simple.ps1";if(Test-Path $f){. $f}'|Out-File "$p\Microsoft.PowerShell_profile.ps1"
Write-Host "Created WinPS5 profile" -Fore Green

$p7="$env:USERPROFILE\Documents\PowerShell"
New-Item -Path $p7 -ItemType Directory -Force -EA SilentlyContinue
'$w="$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1";if(Test-Path $w){. $w}'|Out-File "$p7\Microsoft.PowerShell_profile.ps1"
Write-Host "Created PS7 profile" -Fore Green

$t=schtasks /Query /TN "OpenClaw Gateway" 2>&1|Out-String
if($t-like"*error*"){schtasks /Create /TN "OpenClaw Gateway" /TR "powershell.exe -WindowStyle Hidden -Command Start-Process -FilePath '%APPDATA%\npm\openclaw.cmd' -ArgumentList 'gateway','run','--compact' -WindowStyle Hidden" /SC ONLOGON /DELAY 0000:30 /RL HIGHEST /F|Out-Null;Write-Host "Created autostart" -Fore Green}else{Write-Host "Autostart exists" -Fore Yellow}

$b="$d\start-gateway.bat"
'@echo off'|Out-File $b
'chcp 65001 >nul'|Add-Content $b
'powershell -WindowStyle Hidden -Command "Start-Process -FilePath ''%APPDATA%\npm\openclaw.cmd'' -ArgumentList ''gateway'',''run'',''--compact'' -WindowStyle Hidden -WorkingDirectory ''%USERPROFILE%''"'|Add-Content $b
'pause'|Add-Content $b
Write-Host "Created start-gateway.bat" -Fore Green

Write-Host "Done! Commands: ogstart,ogstop,ogrestart,ogstatus,ogenable,ogdisable" -Fore Cyan
