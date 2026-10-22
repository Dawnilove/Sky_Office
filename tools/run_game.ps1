# 하늘 오피스 개발판 켜기 (켜기.bat 이 부름) — 켜져 있는 하늘 오피스 개발판은 끄고 다시 켬
$godot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine.Mono_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
$game = Join-Path (Split-Path $PSScriptRoot -Parent) 'game'
if (-not (Test-Path $godot)) { Write-Host "Godot 이 없어요: $godot"; Read-Host '엔터를 누르면 닫혀요'; exit 1 }
# 하늘 오피스 개발판만 끔 (다른 Godot 창은 안 건드림)
Get-CimInstance Win32_Process -Filter "Name like 'Godot%'" |
    Where-Object { $_.CommandLine -and $_.CommandLine.Contains($game) } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500
Start-Process -FilePath $godot -ArgumentList @('--path', "`"$game`"")
