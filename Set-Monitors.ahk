#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%
#NoTrayIcon
;Create a variable for a path
path = \Git\PowerShellScripts\
;Press Ctrl + Shift + 0    
^+0::
;Run the Set-MonitorInput.ps1 file in the path with the "-inputchoice Desktop" parameter and don't show the powershell window

Run, powershell.exe -NoProfile -ExecutionPolicy Bypass -File %path%\Set-MonitorInput.ps1 -inputchoice Desktop, , Hide