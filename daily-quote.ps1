<#
    daily-quote.ps1
    Henter et Windows Spotlight-bilde, tegner dagens sitat pent oppå,
    og setter resultatet som skrivebordsbakgrunn.

    Roterer gjennom sitatene i rekkefølge; nytt tilfeldig bilde for hver kjøring.
#>

[CmdletBinding()]
param(
    [string]$QuotesFile  = "$PSScriptRoot\quotes.txt",
    [ValidateSet('BottomLeft', 'BottomCenter', 'Center')]
    [string]$Position    = 'BottomLeft',
    [int]$MinWidth       = 1600   # ignorer små/portrett-assets
)

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$work = Join-Path $env:LOCALAPPDATA 'DailyQuote'
$pool = Join-Path $work 'spotlight'
New-Item -ItemType Directory -Force -Path $work, $pool | Out-Null

# ---------------------------------------------------------------- sitat ----
$quotes = @(Get-Content $QuotesFile -Encoding UTF8 | Where-Object { $_.Trim() })
if (-not $quotes) { throw "Fant ingen sitater i $QuotesFile" }

# Roter gjennom sitatene i rekkefølge; husk sist brukte indeks i state-fil
$stateFile = Join-Path $work 'quote-state.txt'
$prev = -1
if (Test-Path $stateFile) {
    [int]::TryParse((Get-Content $stateFile -Raw -ErrorAction SilentlyContinue), [ref]$prev) | Out-Null
}
$next = (($prev + 1) % $quotes.Count + $quotes.Count) % $quotes.Count
Set-Content $stateFile -Value $next -Encoding UTF8
$quote = $quotes[$next].Trim()

# ------------------------------------------------------ samle spotlight ----
$sources = @(
    Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets'
    Join-Path $env:APPDATA      'Microsoft\Windows\Themes\CachedFiles'
    Join-Path $env:APPDATA      'Microsoft\Windows\Themes'
)

foreach ($src in $sources) {
    if (-not (Test-Path $src)) { continue }
    Get-ChildItem -Path $src -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 250KB } |
        ForEach-Object {
            $dest = Join-Path $pool ($_.BaseName + '.jpg')
            if (-not (Test-Path $dest)) {
                Copy-Item $_.FullName $dest -ErrorAction SilentlyContinue
            }
        }
}

# Kast alt som ikke er brukbart liggende format
Get-ChildItem $pool -Filter *.jpg -File | ForEach-Object {
    try {
        $probe = [System.Drawing.Image]::FromFile($_.FullName)
        $ok = ($probe.Width -ge $MinWidth -and $probe.Width -gt $probe.Height)
        $probe.Dispose()
        if (-not $ok) { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
    } catch {
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
    }
}

$candidates = Get-ChildItem $pool -Filter *.jpg -File
if (-not $candidates) {
    throw "Fant ingen Spotlight-bilder. Slå på Spotlight en dag eller to først (Innstillinger > Personalisering > Bakgrunn > Windows Spotlight), så bygger cachen seg opp."
}

# Nytt bilde hver kjøring
$picture = $candidates | Get-Random

# ---------------------------------------------------------------- tegne ----
$img = [System.Drawing.Image]::FromFile($picture.FullName)
$bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
$g   = [System.Drawing.Graphics]::FromImage($bmp)

$g.SmoothingMode      = 'AntiAlias'
$g.InterpolationMode  = 'HighQualityBicubic'
$g.TextRenderingHint  = 'ClearTypeGridFit'
$g.DrawImage($img, 0, 0, $img.Width, $img.Height)
$img.Dispose()

$W = $bmp.Width
$H = $bmp.Height

# Mørk gradient nederst så teksten alltid er lesbar
$scrimH = [int]($H * 0.42)
$scrimRect = New-Object System.Drawing.Rectangle(0, ($H - $scrimH), $W, $scrimH)
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $scrimRect,
    [System.Drawing.Color]::FromArgb(0, 0, 0, 0),
    [System.Drawing.Color]::FromArgb(215, 0, 0, 0),
    90.0)
$g.FillRectangle($grad, $scrimRect)
$grad.Dispose()

# Tekstboks
$margin = [int]($W * 0.065)
switch ($Position) {
    'Center'       { $boxY = [int]($H * 0.38); $align = 'Center' }
    'BottomCenter' { $boxY = [int]($H * 0.66); $align = 'Center' }
    default        { $boxY = [int]($H * 0.68); $align = 'Near'   }
}
$boxW = $W - (2 * $margin)
$boxH = $H - $boxY - [int]($H * 0.10)

$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment     = $align
$fmt.LineAlignment = 'Near'
$fmt.Trimming      = 'Word'

# Autoskaler fonten ned til sitatet får plass
$size = [float]($W * 0.038)
do {
    if ($font) { $font.Dispose() }
    $font = New-Object System.Drawing.Font('Segoe UI Light', $size, [System.Drawing.FontStyle]::Regular)
    $measured = $g.MeasureString($quote, $font, [int]$boxW, $fmt)
    if ($measured.Height -le $boxH -or $size -le 18) { break }
    $size = $size * 0.92
} while ($true)

$rect = New-Object System.Drawing.RectangleF($margin, $boxY, $boxW, $boxH)

# Myk skygge for kontrast, så selve teksten
$shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 0, 0, 0))
$offset = [math]::Max(2, [int]($W * 0.0016))
$shadowRect = New-Object System.Drawing.RectangleF(($margin + $offset), ($boxY + $offset), $boxW, $boxH)
$g.DrawString($quote, $font, $shadow, $shadowRect, $fmt)
$shadow.Dispose()

$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 255, 255, 255))
$g.DrawString($quote, $font, $brush, $rect, $fmt)
$brush.Dispose()
$font.Dispose()

# Diskré liten strek over teksten
$pen = New-Object System.Drawing.Pen(
    [System.Drawing.Color]::FromArgb(170, 255, 255, 255),
    [math]::Max(2, [int]($W * 0.0018)))
$lineY = $boxY - [int]($H * 0.035)
switch ($align) {
    'Center' { $g.DrawLine($pen, ($W / 2 - $W * 0.03), $lineY, ($W / 2 + $W * 0.03), $lineY) }
    default  { $g.DrawLine($pen, $margin, $lineY, ($margin + $W * 0.06), $lineY) }
}
$pen.Dispose()
$g.Dispose()

# ------------------------------------------------------------ lagre/sett ----
# Nytt filnavn hver gang: Windows cacher bakgrunn per filsti
Get-ChildItem $work -Filter 'wallpaper-*.jpg' -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

$out = Join-Path $work ("wallpaper-{0}.jpg" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
         Where-Object { $_.MimeType -eq 'image/jpeg' }
$params = New-Object System.Drawing.Imaging.EncoderParameters(1)
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality, [int64]92)
$bmp.Save($out, $codec, $params)
$bmp.Dispose()

# Fyll-modus
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'

if (-not ('WallpaperNative' -as [type])) {
    Add-Type @'
using System.Runtime.InteropServices;
public class WallpaperNative {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
}
[WallpaperNative]::SystemParametersInfo(20, 0, $out, 3) | Out-Null

Write-Host "Satt bakgrunn: $quote"
Write-Host "Bilde: $($picture.Name)"
