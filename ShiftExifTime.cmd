@echo off
rem Each offset part may have its own sign.
set "HOURS_OFFSET=5"
set "MINUTES_OFFSET=-4"
set "SECONDS_OFFSET=-10"

rem Empty value means: do not change EXIF timezone fields.
rem Example: set "TIME_ZONE_OFFSET=+08:00"
set "TIME_ZONE_OFFSET=+08:00"

rem Switch to the script folder and process files from this folder.
pushd "%~dp0"
if defined TIME_ZONE_OFFSET (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ShiftExifTime.ps1" -HoursOffset %HOURS_OFFSET% -MinutesOffset %MINUTES_OFFSET% -SecondsOffset %SECONDS_OFFSET% -TimeZoneOffset "%TIME_ZONE_OFFSET%" -TargetFolder "%CD%"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ShiftExifTime.ps1" -HoursOffset %HOURS_OFFSET% -MinutesOffset %MINUTES_OFFSET% -SecondsOffset %SECONDS_OFFSET% -TargetFolder "%CD%"
)
rem Return to the previous folder if you run this from an existing console.
rem popd
pause
