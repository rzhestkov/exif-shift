@echo off
set "HOURS_OFFSET=2"
set "MINUTES_OFFSET=0"
set "SECONDS_OFFSET=0"

pushd "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ShiftExifTime.ps1" -HoursOffset %HOURS_OFFSET% -MinutesOffset %MINUTES_OFFSET% -SecondsOffset %SECONDS_OFFSET% -TargetFolder "%CD%"
popd
pause
