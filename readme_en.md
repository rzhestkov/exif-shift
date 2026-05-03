# ShiftExifTime

A PowerShell script for batch-shifting the capture time of Canon photos (`.CR3`, `.JPG`, `.JPEG`). The script updates EXIF date fields and the file's Modified date attribute. It is useful for correcting capture times after trips and time zone changes.

The project helps bring photos from different devices onto one correct timeline. A typical scenario: some shots were taken with a phone that gets the exact time and time zone from the network, while others were taken with a camera that uses its internal clock. The camera may have not only the wrong time zone, but also a small clock drift forward or backward.

The script lets you manually calculate the required correction and apply it to an entire photo series: shift hours, minutes, and seconds, and optionally write a new time zone to EXIF. This helps Lightroom and other programs sort photos correctly by capture time.

## Why this script exists

The script solves several practical problems that often appear after trips and shooting with different devices:

- aligns camera time with a reference phone photo;
- compensates for camera clock drift when the internal clock has run slightly fast or slow;
- lets you correct not only hours, but also minutes and seconds;
- keeps time zone changes optional, because Lightroom usually sorts by the visible capture time, while other programs may take EXIF offset fields into account;
- makes a risky operation a little safer by asking for explicit confirmation before changing files.

## What this script does

- finds photos in supported formats in the selected folder;
- shifts `DateTimeOriginal`, `CreateDate`, `ModifyDate`, and `FileModifyDate`;
- combines `HoursOffset`, `MinutesOffset`, and `SecondsOffset` into one final shift, so each parameter may have its own sign;
- when `TimeZoneOffset` is provided, writes the new time zone to `OffsetTime`, `OffsetTimeOriginal`, and `OffsetTimeDigitized`;
- runs the local `exiftool.exe` and overwrites original files without creating backups.

## Files

- **ShiftExifTime.ps1** - the main PowerShell script.
- **ShiftExifTime.cmd** - a convenient launcher with predefined parameters.
- **exiftool.exe** - the ExifTool utility; it must be placed next to the script.

## How it works

1. The script accepts hour, minute, and second offsets.
2. All components are combined into one final shift. Mixed signs are handled correctly: `-HoursOffset 1 -MinutesOffset -30` means a final shift of `+30` minutes.
3. If `-TimeZoneOffset` is provided, the script sets the new time zone in the EXIF fields `OffsetTime`, `OffsetTimeOriginal`, and `OffsetTimeDigitized`. By default, the time zone is not changed. Changing `-TimeZoneOffset` is optional, because Lightroom does not use it when sorting and processing photos. It is included in case Lightroom changes this behavior, or other current or future programs rely on these fields.
4. The script looks for `exiftool.exe` in the script directory. If it is missing, the script reports an error.
5. For each file with the `.cr3`, `.jpg`, or `.jpeg` extension in the target folder (without recursion), the script makes a single ExifTool call:

```powershell
exiftool -AllDates+=<h:mm:ss> -FileModifyDate+=<h:mm:ss> -overwrite_original <file>
```

For a negative final shift, the `-=` operator is used instead of `+=`.

This operation shifts:

- the EXIF tags `DateTimeOriginal`, `CreateDate`, and `ModifyDate`;
- the file Modify date attribute (`FileModifyDate` / `LastWriteTime`);
- if `-TimeZoneOffset` is provided, the EXIF time zone fields;
- the original file is overwritten without a backup copy.

## Requirements

- Windows PowerShell 5.1 or newer.
- `exiftool.exe` next to the script.
- Permission to run PowerShell scripts, for example:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

## Parameters

- **-HoursOffset** / **-Hours** (int) - shift in hours.
- **-MinutesOffset** / **-Minutes** (int) - shift in minutes.
- **-SecondsOffset** / **-Seconds** (int) - shift in seconds.
- **-TimeZoneOffset** / **-TZ** (string) - the new time zone in `+08:00` or `-03:30` format. If omitted, the time zone is not changed.
- **-TargetFolder** (string) - folder with files. Defaults to the current folder.

At least one action parameter must be provided: a time shift or `-TimeZoneOffset`. If the final shift is zero and no time zone is specified, the script changes nothing.

## Usage examples

```powershell
# Shift by +2 hours in the current folder
.\ShiftExifTime.ps1 -HoursOffset 2

# Shift by -1 hour in the specified folder
.\ShiftExifTime.ps1 -HoursOffset -1 -TargetFolder "C:\Photos"

# Shift by +2 hours 15 minutes
.\ShiftExifTime.ps1 -HoursOffset 2 -MinutesOffset 15

# Shift backward by 45 seconds
.\ShiftExifTime.ps1 -SecondsOffset -45

# Mixed signs: final shift will be +30 minutes
.\ShiftExifTime.ps1 -HoursOffset 1 -MinutesOffset -30

# Shift time and set the time zone to +08:00
.\ShiftExifTime.ps1 -HoursOffset 5 -MinutesOffset -4 -SecondsOffset 10 -TimeZoneOffset "+08:00"

# Only set the time zone, without changing capture time
.\ShiftExifTime.ps1 -TimeZoneOffset "+08:00"
```

## Quick launch through CMD

In `ShiftExifTime.cmd`, you can change the values at the beginning of the file:

```bat
set "HOURS_OFFSET=2"
set "MINUTES_OFFSET=0"
set "SECONDS_OFFSET=0"
set "TIME_ZONE_OFFSET="
```

To set the time zone together with the shift, fill in `TIME_ZONE_OFFSET`, for example `+08:00`.

After that, you can run the `.cmd` file by double-clicking it.

## Notes

- The script asks for confirmation before making changes.
- A single ExifTool call changes both EXIF tags and the file timestamp.
- Original files are overwritten without creating backup copies (`-overwrite_original`).
- If you need to process files recursively in subfolders, you can add `-Recurse` to the `Get-ChildItem` command inside the script.
