@echo off
rem gdsh-cli wrapper: forwards to gdsh-cli.ps1 next to it. Named gdsh.cmd so `gdsh` resolves to it
rem from cmd and PowerShell whatever the execution policy; the .ps1's other name keeps PowerShell off it.
where pwsh >nul 2>nul
if %errorlevel% equ 0 (
	pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0gdsh-cli.ps1" %*
) else (
	powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gdsh-cli.ps1" %*
)
exit /b %errorlevel%
