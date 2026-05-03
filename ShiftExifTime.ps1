<#
.SYNOPSIS
  Сдвигает EXIF- и файловые даты фотографий на заданное время.
.DESCRIPTION
  - EXIF-теги: DateTimeOriginal, CreateDate, ModifyDate  
  - Файловый атрибут: FileModifyDate (LastWriteTime)  
  - Всегда перезаписывает оригиналы без резервных копий.  
  - Перед изменениями спрашивает подтверждение у пользователя.  
  - Для каждого файла выводит «Успешно!» зелёным или «Ошибка!» красным, но продолжает обработку остальных.
.PARAMETER HoursOffset
  Смещение времени в часах (целое, может быть отрицательным).
.PARAMETER MinutesOffset
  Смещение времени в минутах (целое, может быть отрицательным).
.PARAMETER SecondsOffset
  Смещение времени в секундах (целое, может быть отрицательным).
.PARAMETER TargetFolder
  Папка с файлами; по умолчанию — текущая (`.`).
#>
[CmdletBinding()]
param(
  [Alias('Hours')]
  [int]    $HoursOffset = 0,

  [Alias('Minutes')]
  [int]    $MinutesOffset = 0,

  [Alias('Seconds')]
  [int]    $SecondsOffset = 0,

  [string] $TargetFolder = "."
)

# 1) Проверяем, что указан хотя бы один компонент смещения
$OffsetParameterNames = @('HoursOffset', 'MinutesOffset', 'SecondsOffset')
$HasOffsetParameter = $false
foreach ($name in $OffsetParameterNames) {
  if ($PSBoundParameters.ContainsKey($name)) {
    $HasOffsetParameter = $true
    break
  }
}

if (-not $HasOffsetParameter) {
  Write-Warning "Не указано смещение времени. Используйте -HoursOffset, -MinutesOffset или -SecondsOffset. Ничего не делаем."
  return
}

# 2) Сводим часы, минуты и секунды к одному итоговому сдвигу.
# Это корректно обрабатывает смешанные знаки, например: -HoursOffset 1 -MinutesOffset -30 = +30 минут.
$TotalSeconds = [int64]$HoursOffset * 3600 + [int64]$MinutesOffset * 60 + [int64]$SecondsOffset

if ($TotalSeconds -eq 0) {
  Write-Warning "Итоговое смещение равно 0 секунд. Ничего не делаем."
  return
}

# 3) Ищем exiftool.exe рядом со скриптом
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ExifTool = Join-Path $ScriptDir "exiftool.exe"
if (-not (Test-Path $ExifTool)) {
  Throw "Не найден exiftool.exe в каталоге скрипта: $ScriptDir"
}

# 4) Проверяем целевую папку
$TargetFolderInfo = Resolve-Path -LiteralPath $TargetFolder -ErrorAction SilentlyContinue
if (-not $TargetFolderInfo) {
  Write-Warning "Целевая папка не найдена: '$TargetFolder'. Ничего не делаем."
  return
}
$TargetFolderPath = $TargetFolderInfo.ProviderPath

# 5) Формируем спецификацию смещения h:m:s и отдельный оператор направления для ExifTool.
$ShiftOperator = if ($TotalSeconds -gt 0) { '+=' } else { '-=' }
$AbsTotalSeconds = [math]::Abs($TotalSeconds)
$AbsHours = [int64][math]::Floor($AbsTotalSeconds / 3600)
$AbsMinutes = [int64][math]::Floor(($AbsTotalSeconds % 3600) / 60)
$AbsSeconds = [int64]($AbsTotalSeconds % 60)
$ShiftSpec = "{0}:{1:D2}:{2:D2}" -f $AbsHours, $AbsMinutes, $AbsSeconds
$HumanShift = "{0}{1}" -f $(if ($TotalSeconds -gt 0) { '+' } else { '-' }), $ShiftSpec

# 6) Собираем список файлов .cr3, .jpg и .jpeg в целевой папке
$SupportedExtensions = @(".cr3", ".jpg", ".jpeg")
$files = @(Get-ChildItem -LiteralPath $TargetFolderPath -File |
Where-Object { $SupportedExtensions -contains $_.Extension.ToLower() })

if ($files.Count -eq 0) {
  Write-Host "Не найдено файлов .cr3, .jpg или .jpeg в папке '$TargetFolderPath'." -ForegroundColor Yellow
  return
}

# 7) Подтверждение перед изменениями
$prompt = "Файлы будут изменены необратимо. Смещение: $HumanShift. Продолжить? [Y/N]"
Write-Host $prompt -ForegroundColor Yellow -NoNewline
$answer = Read-Host " "
if ($answer -notin 'Y', 'y') {
  Write-Host "Операция отменена пользователем." -ForegroundColor Red
  return
}

# 8) Задаём кодировку CP1251 для русских имён
$CharsetParams = @('-charset', 'filename=cp1251')
$AllDatesShiftArg = "-AllDates$ShiftOperator$ShiftSpec"
$FileModifyDateShiftArg = "-FileModifyDate$ShiftOperator$ShiftSpec"

# 9) Обработка каждого файла
foreach ($f in $files) {
  Write-Host "Обрабатываю '$($f.Name)'..." -NoNewline

  & $ExifTool @CharsetParams `
    $AllDatesShiftArg `
    $FileModifyDateShiftArg `
    "-overwrite_original" `
    $f.FullName | Out-Null

  if ($LASTEXITCODE -eq 0) {
    Write-Host " Успешно!" -ForegroundColor Green
  }
  else {
    Write-Host " Ошибка!" -ForegroundColor Red
  }
}

Write-Host "Готово." -ForegroundColor Green
