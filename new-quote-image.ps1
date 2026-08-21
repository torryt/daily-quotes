<#
    New-QuoteImage.ps1
    Draws a quote onto an image (BottomLeft) in the same style as
    daily-quote.ps1, and saves the result as a timestamped JPEG.

    Usage:
        .\New-QuoteImage.ps1 -Quote "Stay hungry, stay foolish." -ImagePath .\photo.jpg

    Returns the path to the generated image.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Quote,
    [Parameter(Mandatory)][string]$ImagePath,
    # Where to write the output; defaults to the source image's folder
    [string]$OutputDirectory,
    # Where the quote text is placed on the image
    [ValidateSet('TopLeft','TopCenter','TopRight',
                 'MiddleLeft','Center','MiddleRight',
                 'BottomLeft','BottomCenter','BottomRight')]
    [string]$Placement = 'BottomLeft'
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$Quote = $Quote.Trim()
if (-not $Quote) { throw "Quote is empty." }
if (-not (Test-Path -LiteralPath $ImagePath)) { throw "Image not found: $ImagePath" }

$src = Get-Item -LiteralPath $ImagePath
if (-not $OutputDirectory) { $OutputDirectory = $src.DirectoryName }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

# ---------------------------------------------------------------- draw ----
$img = [System.Drawing.Image]::FromFile($src.FullName)
$bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
$g   = [System.Drawing.Graphics]::FromImage($bmp)

$g.SmoothingMode      = 'AntiAlias'
$g.InterpolationMode  = 'HighQualityBicubic'
$g.TextRenderingHint  = 'ClearTypeGridFit'
$g.DrawImage($img, 0, 0, $img.Width, $img.Height)
$img.Dispose()

$W = $bmp.Width
$H = $bmp.Height

# Resolve the requested placement into vertical / horizontal components
if ($Placement -eq 'Center')        { $vPos = 'Middle' }
elseif ($Placement -like 'Top*')    { $vPos = 'Top' }
elseif ($Placement -like 'Middle*') { $vPos = 'Middle' }
else                                { $vPos = 'Bottom' }

if ($Placement -like '*Left')      { $hPos = 'Left' }
elseif ($Placement -like '*Right') { $hPos = 'Right' }
else                               { $hPos = 'Center' }

# Text box geometry
$margin = [int]($W * 0.065)
$boxW   = $W - (2 * $margin)
$boxH   = [int]($H * 0.22)
switch ($vPos) {
    'Top'    { $boxY = [int]($H * 0.10) }
    'Middle' { $boxY = [int](($H - $boxH) / 2) }
    default  { $boxY = $H - $boxH - [int]($H * 0.10) }
}
switch ($hPos) {
    'Center' { $align = 'Center' }
    'Right'  { $align = 'Far' }
    default  { $align = 'Near' }
}

# Dark gradient behind the text so it is always readable
$scrimH = [int]($H * 0.42)
switch ($vPos) {
    'Top'    { $scrimRect = New-Object System.Drawing.Rectangle(0, 0, $W, $scrimH); $gradAngle = 270.0 }
    'Middle' { $scrimRect = New-Object System.Drawing.Rectangle(0, [int](($H - $scrimH) / 2), $W, $scrimH); $gradAngle = 90.0 }
    default  { $scrimRect = New-Object System.Drawing.Rectangle(0, ($H - $scrimH), $W, $scrimH); $gradAngle = 90.0 }
}
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $scrimRect,
    [System.Drawing.Color]::FromArgb(0, 0, 0, 0),
    [System.Drawing.Color]::FromArgb(215, 0, 0, 0),
    $gradAngle)
# Avoid 1-pixel artifact (black line) at gradient edge
$grad.WrapMode = [System.Drawing.Drawing2D.WrapMode]::TileFlipXY
$g.FillRectangle($grad, $scrimRect)
$grad.Dispose()

$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment     = $align
$fmt.LineAlignment = 'Near'
$fmt.Trimming      = 'Word'

# Auto-scale font down until quote fits
$size = [float]($W * 0.038)
do {
    if ($font) { $font.Dispose() }
    $font = New-Object System.Drawing.Font('Segoe UI Light', $size, [System.Drawing.FontStyle]::Regular)
    $measured = $g.MeasureString($Quote, $font, [int]$boxW, $fmt)
    if ($measured.Height -le $boxH -or $size -le 18) { break }
    $size = $size * 0.92
} while ($true)

$rect = New-Object System.Drawing.RectangleF($margin, $boxY, $boxW, $boxH)

# Soft shadow for contrast, then the actual text
$shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 0, 0, 0))
$offset = [math]::Max(2, [int]($W * 0.0016))
$shadowRect = New-Object System.Drawing.RectangleF(($margin + $offset), ($boxY + $offset), $boxW, $boxH)
$g.DrawString($Quote, $font, $shadow, $shadowRect, $fmt)
$shadow.Dispose()

$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 255, 255, 255))
$g.DrawString($Quote, $font, $brush, $rect, $fmt)
$brush.Dispose()
$font.Dispose()

# Discreet small line near the text
$pen = New-Object System.Drawing.Pen(
    [System.Drawing.Color]::FromArgb(170, 255, 255, 255),
    [math]::Max(2, [int]($W * 0.0018)))
$lineLen = [int]($W * 0.06)
switch ($hPos) {
    'Center' { $lineX = [int]($margin + ($boxW - $lineLen) / 2) }
    'Right'  { $lineX = [int]($W - $margin - $lineLen) }
    default  { $lineX = $margin }
}
if ($vPos -eq 'Top') { $lineY = $boxY + $boxH + [int]($H * 0.015) }
else                 { $lineY = $boxY - [int]($H * 0.035) }
$g.DrawLine($pen, $lineX, $lineY, ($lineX + $lineLen), $lineY)
$pen.Dispose()
$g.Dispose()

# ------------------------------------------------------------ save ----
# Timestamped filename, derived from the source image's base name
$out = Join-Path $OutputDirectory ("{0}-{1}.jpg" -f $src.BaseName, (Get-Date -Format 'yyyyMMdd-HHmmss'))

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
         Where-Object { $_.MimeType -eq 'image/jpeg' }
$params = New-Object System.Drawing.Imaging.EncoderParameters(1)
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality, [int64]92)
$bmp.Save($out, $codec, $params)
$bmp.Dispose()

Write-Host "Saved: $out"
return $out
