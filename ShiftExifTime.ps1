#  Сдвигает EXIF- и файловые даты фотографий на заданное время.
#  - EXIF-теги: DateTimeOriginal, CreateDate, ModifyDate  
#  - Файловый атрибут: FileModifyDate (LastWriteTime)  
#  - Всегда перезаписывает оригиналы без резервных копий.  
#  - Перед изменениями спрашивает подтверждение у пользователя.  
#  - Для каждого файла выводит «Успешно!» зелёным или «Ошибка!» красным, но продолжает обработку остальных.
# HoursOffset - Смещение времени в часах (целое, может быть отрицательным)
# MinutesOffset - Смещение времени в минутах (целое, может быть отрицательным)
# SecondsOffset - Смещение времени в секундах (целое, может быть отрицательным)
# Каждый параметр может быть со своим знаком
# TimeZoneOffset - Новый часовой пояс в формате +08:00 или -03:30. По умолчанию не меняется.
# TargetFolder - Папка с файлами; по умолчанию — текущая (`.`).
[CmdletBinding()]
param(
  [Alias('Hours')]
  [int]    $HoursOffset = 0,

  [Alias('Minutes')]
  [int]    $MinutesOffset = 0,

  [Alias('Seconds')]
  [int]    $SecondsOffset = 0,

  [Alias('TZ')]
  [string] $TimeZoneOffset,

  [string] $TargetFolder = "."
)

# 1) Проверяем, что указано хотя бы одно действие: сдвиг времени или установка часового пояса
$OffsetParameterNames = @('HoursOffset', 'MinutesOffset', 'SecondsOffset')
$HasOffsetParameter = $false
foreach ($name in $OffsetParameterNames) {
  if ($PSBoundParameters.ContainsKey($name)) {
    $HasOffsetParameter = $true
    break
  }
}
$HasTimeZoneOffset = $PSBoundParameters.ContainsKey('TimeZoneOffset')

if (-not $HasOffsetParameter -and -not $HasTimeZoneOffset) {
  Write-Warning "Не указано действие. Используйте параметры смещения времени или -TimeZoneOffset. Ничего не делаем."
  return
}

# 2) Проверяем и нормализуем часовой пояс, если он указан.
$NormalizedTimeZoneOffset = $null
if ($HasTimeZoneOffset) {
  if ([string]::IsNullOrWhiteSpace($TimeZoneOffset)) {
    Write-Warning "Параметр -TimeZoneOffset указан пустым. Используйте формат +08:00 или -03:30."
    return
  }

  $TrimmedTimeZoneOffset = $TimeZoneOffset.Trim()
  if ($TrimmedTimeZoneOffset -notmatch '^([+-])(\d{1,2})(?::?(\d{2}))?$') {
    Write-Warning "Неверный формат -TimeZoneOffset '$TimeZoneOffset'. Используйте формат +08:00 или -03:30."
    return
  }

  $TimeZoneSign = $Matches[1]
  $TimeZoneHours = [int]$Matches[2]
  $TimeZoneMinutes = if ($Matches[3]) { [int]$Matches[3] } else { 0 }

  if ($TimeZoneHours -gt 14 -or $TimeZoneMinutes -gt 59 -or ($TimeZoneHours -eq 14 -and $TimeZoneMinutes -ne 0)) {
    Write-Warning "Неверное значение -TimeZoneOffset '$TimeZoneOffset'. Допустимый диапазон: от -14:00 до +14:00."
    return
  }

  $NormalizedTimeZoneOffset = "{0}{1:D2}:{2:D2}" -f $TimeZoneSign, $TimeZoneHours, $TimeZoneMinutes
}

# 3) Сводим часы, минуты и секунды к одному итоговому сдвигу.
# Это корректно обрабатывает смешанные знаки, например: -HoursOffset 1 -MinutesOffset -30 = +30 минут.
$TotalSeconds = [int64]$HoursOffset * 3600 + [int64]$MinutesOffset * 60 + [int64]$SecondsOffset

if ($TotalSeconds -eq 0 -and -not $HasTimeZoneOffset) {
  Write-Warning "Итоговое смещение равно 0 секунд. Ничего не делаем."
  return
}

# 4) Ищем exiftool.exe рядом со скриптом
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ExifTool = Join-Path $ScriptDir "exiftool.exe"
if (-not (Test-Path $ExifTool)) {
  Throw "Не найден exiftool.exe в каталоге скрипта: $ScriptDir"
}

# 5) Проверяем целевую папку
$TargetFolderInfo = Resolve-Path -LiteralPath $TargetFolder -ErrorAction SilentlyContinue
if (-not $TargetFolderInfo) {
  Write-Warning "Целевая папка не найдена: '$TargetFolder'. Ничего не делаем."
  return
}
$TargetFolderPath = $TargetFolderInfo.ProviderPath

# 6) Формируем спецификацию смещения h:m:s и отдельный оператор направления для ExifTool.
$ShiftOperator = $null
$ShiftSpec = $null
$HumanShift = "нет"
if ($TotalSeconds -ne 0) {
  $ShiftOperator = if ($TotalSeconds -gt 0) { '+=' } else { '-=' }
  $AbsTotalSeconds = [math]::Abs($TotalSeconds)
  $AbsHours = [int64][math]::Floor($AbsTotalSeconds / 3600)
  $AbsMinutes = [int64][math]::Floor(($AbsTotalSeconds % 3600) / 60)
  $AbsSeconds = [int64]($AbsTotalSeconds % 60)
  $ShiftSpec = "{0}:{1:D2}:{2:D2}" -f $AbsHours, $AbsMinutes, $AbsSeconds
  $HumanShift = "{0}{1}" -f $(if ($TotalSeconds -gt 0) { '+' } else { '-' }), $ShiftSpec
}

# 7) Собираем список файлов .cr3, .jpg и .jpeg в целевой папке
$SupportedExtensions = @(".cr3", ".jpg", ".jpeg")
$files = @(Get-ChildItem -LiteralPath $TargetFolderPath -File |
Where-Object { $SupportedExtensions -contains $_.Extension.ToLower() })

if ($files.Count -eq 0) {
  Write-Host "Не найдено файлов .cr3, .jpg или .jpeg в папке '$TargetFolderPath'." -ForegroundColor Yellow
  return
}

# 8) Подтверждение перед изменениями
$TimeZoneText = if ($HasTimeZoneOffset) { $NormalizedTimeZoneOffset } else { "не менять" }
$prompt = "Файлы будут изменены необратимо. Смещение: $HumanShift. Часовой пояс: $TimeZoneText. Продолжить? [Y/N]"
Write-Host $prompt -ForegroundColor Yellow -NoNewline
$answer = Read-Host " "
if ($answer -notin 'Y', 'y') {
  Write-Host "Операция отменена пользователем." -ForegroundColor Red
  return
}

# 9) Задаём кодировку CP1251 для русских имён
$CharsetParams = @('-charset', 'filename=cp1251')
$ExifToolActionArgs = @()
if ($TotalSeconds -ne 0) {
  $ExifToolActionArgs += "-AllDates$ShiftOperator$ShiftSpec"
  $ExifToolActionArgs += "-FileModifyDate$ShiftOperator$ShiftSpec"
}
if ($HasTimeZoneOffset) {
  $ExifToolActionArgs += "-OffsetTime=$NormalizedTimeZoneOffset"
  $ExifToolActionArgs += "-OffsetTimeOriginal=$NormalizedTimeZoneOffset"
  $ExifToolActionArgs += "-OffsetTimeDigitized=$NormalizedTimeZoneOffset"
}

# 10) Обработка каждого файла
foreach ($f in $files) {
  Write-Host "Обрабатываю '$($f.Name)'..." -NoNewline

  & $ExifTool @CharsetParams `
    @ExifToolActionArgs `
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
