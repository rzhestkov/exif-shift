# ShiftExifTime

Скрипт на PowerShell для массового сдвига времени у фотографий Canon (`.CR3`, `.JPG`, `.JPEG`). Время меняется в EXIF-датах и файловом атрибуте Modified date. Полезно для коррекции времени съемки после поездок и смены часового пояса.

## Файлы

- **ShiftExifTime.ps1** — основной PowerShell-скрипт.
- **ShiftExifTime.cmd** — удобный запуск с заранее заданными параметрами.
- **exiftool.exe** — утилита ExifTool, должна лежать рядом со скриптом.

## Логика работы

1. Скрипт принимает смещение по часам, минутам и секундам.
2. Все компоненты складываются в один итоговый сдвиг. Смешанные знаки обрабатываются корректно: `-HoursOffset 1 -MinutesOffset -30` означает итоговые `+30` минут.
3. Находится `exiftool.exe` в каталоге скрипта. При отсутствии будет ошибка.
4. Для каждого файла с расширением `.cr3`, `.jpg` или `.jpeg` в целевой папке (без рекурсии) делается единый вызов ExifTool:

```powershell
exiftool -AllDates+=<h:mm:ss> -FileModifyDate+=<h:mm:ss> -overwrite_original <файл>
```

Для отрицательного итогового сдвига используется оператор `-=` вместо `+=`.

Эта операция сдвигает:

- EXIF-теги `DateTimeOriginal`, `CreateDate` и `ModifyDate`;
- файловый атрибут Modify date (`FileModifyDate` / `LastWriteTime`);
- оригинальный файл перезаписывается без резервной копии.

## Требования

- Windows PowerShell 5.1 или новее.
- `exiftool.exe` рядом со скриптом.
- Разрешение на выполнение скриптов PowerShell, например:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

## Параметры

- **-HoursOffset** / **-Hours** (int) — смещение в часах.
- **-MinutesOffset** / **-Minutes** (int) — смещение в минутах.
- **-SecondsOffset** / **-Seconds** (int) — смещение в секундах.
- **-TargetFolder** (string) — папка с файлами. По умолчанию текущая папка.

Нужно указать хотя бы один из параметров смещения. Если итоговое смещение равно нулю, скрипт ничего не меняет.

## Способы использования

```powershell
# Сдвинуть на +2 часа в текущей папке
.\ShiftExifTime.ps1 -HoursOffset 2

# Сдвинуть на -1 час в указанной папке
.\ShiftExifTime.ps1 -HoursOffset -1 -TargetFolder "C:\Photos"

# Сдвинуть на +2 часа 15 минут
.\ShiftExifTime.ps1 -HoursOffset 2 -MinutesOffset 15

# Сдвинуть назад на 45 секунд
.\ShiftExifTime.ps1 -SecondsOffset -45

# Смешанные знаки: итоговый сдвиг будет +30 минут
.\ShiftExifTime.ps1 -HoursOffset 1 -MinutesOffset -30
```

## Быстрый запуск через CMD

В `ShiftExifTime.cmd` можно поменять значения в начале файла:

```bat
set "HOURS_OFFSET=2"
set "MINUTES_OFFSET=0"
set "SECONDS_OFFSET=0"
```

После этого можно запускать `.cmd` двойным кликом.

## Особенности

- Перед изменениями скрипт спрашивает подтверждение.
- Единый вызов ExifTool меняет и EXIF-теги, и файловый штамп.
- Оригинальные файлы перезаписываются без создания резервных копий (`-overwrite_original`).
- Если нужно изменить файлы рекурсивно по подпапкам, можно добавить `-Recurse` к команде `Get-ChildItem` внутри скрипта.
