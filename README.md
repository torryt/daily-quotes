# DailyQuote

Draws today's quote nicely on a Windows Spotlight image and sets it as desktop wallpaper.

Windows Spotlight gives you new background images, but no way to add anything on top. DailyQuote fetches fresh images directly from Spotlight's public API (same source as Windows 11 uses), draws a quote at the bottom with a dark gradient behind it, and sets the result as wallpaper. The local Spotlight cache is used as a fallback if the API is unavailable. You still get new images throughout the day — just with text on them.

New quote in order each run, new image every four hours.

## Requirements

- Windows 10/11
- PowerShell 5.1 (comes with Windows)
- Internet access to fetch fresh images from Spotlight API (without internet the script falls back to the local Spotlight cache)

## Getting Started

Place all files in the same directory, e.g. `C:\dev\tools\DailyQuote\`:

```powershell
Unblock-File .\*.ps1     # removes the download mark
.\install-task.ps1
```

`install-task.ps1` registers a scheduled task (no admin required) and runs the script immediately, so you see the result right away.

To test without registering anything:

```powershell
.\daily-quote.ps1
```

## Files

| File | What it does |
| --- | --- |
| `daily-quote.ps1` | The main job: selects quote and image, draws, sets wallpaper |
| `quotes.txt` | The quotes, one per line, UTF-8 |
| `install-task.ps1` | Registers scheduled task on login + every 4 hours |

## Custom Quotes

Edit `quotes.txt` — one quote per line. The file is read at each run, so you don't need to re-register the task. Save as UTF-8 if you use special characters.

Short quotes look best. The font scales down automatically if the text is too long to fit, but under about 60 characters it stays on one or two lines.

## Parameters

```powershell
.\daily-quote.ps1 -Position BottomCenter
```

| Parameter | Default | Description |
| --- | --- | --- |
| `-QuotesFile` | `.\quotes.txt` | Path to quotes file |
| `-Position` | `BottomLeft` | `BottomLeft`, `BottomCenter` or `Center` |
| `-MinWidth` | `1600` | Minimum image width. Filters out small images and portrait format |

## How It Works

Fresh images are fetched from Spotlight's public API:

```
https://fd.api.iris.microsoft.com/v4/api/selection?placement=88000820&bcnt=8&country=US&locale=en-US&fmt=json
```

`placement=88000820` is desktop spotlight. The response is JSON where each element contains a URL to a landscape image in full resolution (typically 3840×2160) on Microsoft's public CDN (`res.public.onecdn.static.microsoft`). The script downloads these to `%LOCALAPPDATA%\DailyQuote\spotlight\`, deduplicated on `entityId`. If you want images tailored to another country, you can adjust `country`/`locale` in the URL.

As a fallback — if the API doesn't respond — images are copied from the local Spotlight cache, which lands in two places on disk without file extension:

```
%LOCALAPPDATA%\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets
%APPDATA%\Microsoft\Windows\Themes\CachedFiles
```

Regardless of source, anything that isn't landscape format in sufficient resolution is discarded, and the script randomly picks from the rest. The pool stays, so it grows over time.

Quotes are rotated in order. The last used line index is stored in `%LOCALAPPDATA%\DailyQuote\quote-state.txt`, and each run picks the next line and starts over at the top when the list runs out. If you change `quotes.txt`, the index is safely adjusted so it always stays within the list.

The finished image is saved in `%LOCALAPPDATA%\DailyQuote\` with a timestamp in the filename — Windows caches the wallpaper per file path, so without a new name each time the change wouldn't take effect. The wallpaper is set via `SystemParametersInfo` with `SPI_SETDESKWALLPAPER`.

## Known Limitation

**Spotlight rotation is turned off.** As soon as a custom wallpaper is set, Windows stops rotating. DailyQuote takes over that job — hence the scheduled task every four hours.

If you want the text on top of *live* Spotlight, you'd need a floating window over the desktop instead. Rainmeter is the easiest way, or a small WPF app with `WS_EX_NOACTIVATE` anchored behind icons.

The lock screen is not supported. Windows Spotlight overrides it, and setting it programmatically requires Pro/Enterprise and PersonalizationCSP.

## Troubleshooting

**«cannot be loaded ... not digitally signed»**
The files are marked as downloaded from the internet. `Unblock-File .\*.ps1` removes the mark. Check the current policy with `Get-ExecutionPolicy -List` — `RemoteSigned` only requires a signature on marked files.

**«Found no Spotlight images»**
Both API fetch and local cache failed. Check your internet connection. As a backup you can enable Spotlight under Settings → Personalization → Background → Windows Spotlight and let it run for a couple of days, then the cache will fill up.

**The wallpaper doesn't change**
Check that the task exists and has run:

```powershell
Get-ScheduledTask -TaskName 'DailyQuote Wallpaper' | Get-ScheduledTaskInfo
```

## Uninstalling

```powershell
Unregister-ScheduledTask -TaskName 'DailyQuote Wallpaper' -Confirm:$false
Remove-Item "$env:LOCALAPPDATA\DailyQuote" -Recurse -Force
```

Then set the wallpaper back to Spotlight under Settings → Personalization → Background.