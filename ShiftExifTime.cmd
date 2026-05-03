@echo off
rem Каждый параметр может быть со своим знаком
set "HOURS_OFFSET=5"
set "MINUTES_OFFSET=-4"
set "SECONDS_OFFSET=10"

rem Переход в папку расположения скрипта и запуск
pushd "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ShiftExifTime.ps1" -HoursOffset %HOURS_OFFSET% -MinutesOffset %MINUTES_OFFSET% -SecondsOffset %SECONDS_OFFSET% -TargetFolder "%CD%"
rem Возврат в текущую папку
rem popd
pause
