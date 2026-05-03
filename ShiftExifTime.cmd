@echo off
powershell.exe -ExecutionPolicy Bypass -File "ShiftExifTime.ps1"  -HoursOffset 2
pause