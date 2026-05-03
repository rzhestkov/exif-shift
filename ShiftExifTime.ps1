<#
.SYNOPSIS
  Сдвигает EXIF- и файловые даты фотографий на заданное количество часов.
.DESCRIPTION
  - EXIF-теги: DateTimeOriginal, CreateDate, ModifyDate  
  - Файловый атрибут: FileModifyDate (LastWriteTime)  
  - Всегда перезаписывает оригиналы без резервных копий.  
  - Перед изменениями спрашивает подтверждение у пользователя.  
  - Для каждого файла выводит «Успешно!» зелёным или «Ошибка!» красным, но продолжает обработку остальных.
.PARAMETER HoursOffset
  Смещение времени в часах (целое, может быть отрицательным). Обязательно.
.PARAMETER TargetFolder
  Папка с файлами; по умолчанию — текущая (`.`).
#>
[CmdletBinding()]
param(
  [int]    $HoursOffset,
  [string] $TargetFolder = "."
)

# 1) Проверяем, что указан HoursOffset
if (-not $PSBoundParameters.ContainsKey('HoursOffset')) {
  Write-Warning "Не указан обязательный параметр -HoursOffset. Ничего не делаем."
  return
}

# 2) Ищем exiftool.exe рядом со скриптом
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ExifTool = Join-Path $ScriptDir "exiftool.exe"
if (-not (Test-Path $ExifTool)) {
  Throw "Не найден exiftool.exe в каталоге скрипта: $ScriptDir"
}

# 3) Формируем спецификацию смещения H:00:00
$ShiftSpec = "{0}:00:00" -f $HoursOffset

# 4) Собираем список файлов .cr3 и .jpg в целевой папке
$files = Get-ChildItem -Path $TargetFolder -File |
Where-Object { @(".cr3", ".jpg") -contains $_.Extension.ToLower() }

if ($files.Count -eq 0) {
  Write-Host "Не найдено файлов .cr3 или .jpg в папке '$TargetFolder'." -ForegroundColor Yellow
  return
}

# 5) Подтверждение перед изменениями
$prompt = "Файлы будут изменены необратимо. Смещение: $ShiftSpec. Продолжить? [Y/N]"
Write-Host $prompt -ForegroundColor Yellow -NoNewline
$answer = Read-Host " "
if ($answer -notin 'Y', 'y') {
  Write-Host "Операция отменена пользователем." -ForegroundColor Red
  return
}

# 6) Задаём кодировку CP1251 для русских имён
$CharsetParams = @('-charset', 'filename=cp1251')

# 7) Обработка каждого файла
foreach ($f in $files) {
  Write-Host "Обрабатываю '$($f.Name)'..." -NoNewline

  & $ExifTool @CharsetParams `
    "-AllDates+=$ShiftSpec" `
    "-FileModifyDate+=$ShiftSpec" `
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
