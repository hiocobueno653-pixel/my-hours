param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sourceDir = Join-Path $PSScriptRoot 'brand_sources'
$assetDir = Join-Path $ProjectRoot 'assets\brand'
$resDir = Join-Path $ProjectRoot 'android\app\src\main\res'

function New-Canvas([int]$width, [int]$height) {
    return [Drawing.Bitmap]::new(
        $width,
        $height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
}

function Get-AlphaBounds(
    [Drawing.Bitmap]$bitmap,
    [int]$yStart = 0,
    [int]$yEnd = -1
) {
    if ($yEnd -lt 0) { $yEnd = $bitmap.Height }
    $minX = $bitmap.Width
    $minY = $bitmap.Height
    $maxX = -1
    $maxY = -1
    for ($y = $yStart; $y -lt $yEnd; $y++) {
        for ($x = 0; $x -lt $bitmap.Width; $x++) {
            if ($bitmap.GetPixel($x, $y).A -le 8) { continue }
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
    if ($maxX -lt $minX) { throw 'Image contains no visible pixels.' }
    return [Drawing.Rectangle]::new(
        $minX,
        $minY,
        $maxX - $minX + 1,
        $maxY - $minY + 1
    )
}

function New-CroppedBitmap(
    [Drawing.Bitmap]$source,
    [Drawing.Rectangle]$bounds,
    [int]$padding
) {
    $result = New-Canvas (
        $bounds.Width + $padding * 2
    ) (
        $bounds.Height + $padding * 2
    )
    $graphics = [Drawing.Graphics]::FromImage($result)
    try {
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage(
            $source,
            [Drawing.Rectangle]::new(
                $padding,
                $padding,
                $bounds.Width,
                $bounds.Height
            ),
            $bounds,
            [Drawing.GraphicsUnit]::Pixel
        )
    }
    finally {
        $graphics.Dispose()
    }
    return $result
}

function Fit-Bitmap(
    [Drawing.Bitmap]$source,
    [int]$maxWidth,
    [int]$maxHeight
) {
    $scale = [Math]::Min(
        $maxWidth / $source.Width,
        $maxHeight / $source.Height
    )
    $width = [Math]::Max(1, [int][Math]::Round($source.Width * $scale))
    $height = [Math]::Max(1, [int][Math]::Round($source.Height * $scale))
    $result = New-Canvas $width $height
    $graphics = [Drawing.Graphics]::FromImage($result)
    try {
        $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($source, 0, 0, $width, $height)
    }
    finally {
        $graphics.Dispose()
    }
    return $result
}

function New-TintedBitmap(
    [Drawing.Bitmap]$source,
    [Drawing.Color]$color,
    [int]$alphaThreshold = 0
) {
    $result = New-Canvas $source.Width $source.Height
    for ($y = 0; $y -lt $source.Height; $y++) {
        for ($x = 0; $x -lt $source.Width; $x++) {
            $alpha = $source.GetPixel($x, $y).A
            if ($alpha -gt $alphaThreshold) {
                $result.SetPixel(
                    $x,
                    $y,
                    [Drawing.Color]::FromArgb($alpha, $color.R, $color.G, $color.B)
                )
            }
        }
    }
    return $result
}

function Save-Bitmap([Drawing.Bitmap]$bitmap, [string]$path) {
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
}

function New-RoundedPath(
    [single]$x,
    [single]$y,
    [single]$width,
    [single]$height,
    [single]$radius
) {
    $path = [Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $radius * 2
    $path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    $path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
    $path.AddArc(
        $x + $width - $diameter,
        $y + $height - $diameter,
        $diameter,
        $diameter,
        0,
        90
    )
    $path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-LegacyIcon(
    [Drawing.Bitmap]$source,
    [int]$size,
    [bool]$round
) {
    $result = New-Canvas $size $size
    $graphics = [Drawing.Graphics]::FromImage($result)
    try {
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality

        $inset = [single]($size * 0.015)
        $fillRect = [Drawing.RectangleF]::new(
            $inset,
            $inset,
            $size - $inset * 2,
            $size - $inset * 2
        )
        if ($round) {
            $graphics.FillEllipse(
                [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255, 251, 253, 255)),
                $fillRect
            )
        }
        else {
            $radius = [single]($size * 0.22)
            $path = New-RoundedPath `
                $fillRect.X `
                $fillRect.Y `
                $fillRect.Width `
                $fillRect.Height `
                $radius
            $graphics.FillPath(
                [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255, 251, 253, 255)),
                $path
            )
            $path.Dispose()
        }

        $contentWidth = [int][Math]::Round($size * $(if ($round) { 0.74 } else { 0.82 }))
        $contentHeight = [int][Math]::Round(
            $contentWidth * $source.Height / $source.Width
        )
        $x = ($size - $contentWidth) / 2
        $y = ($size - $contentHeight) / 2
        $graphics.DrawImage($source, $x, $y, $contentWidth, $contentHeight)
    }
    finally {
        $graphics.Dispose()
    }
    return $result
}

$iconSource = [Drawing.Bitmap]::FromFile(
    (Join-Path $sourceDir 'app_icon.png')
)
$welcomeSource = [Drawing.Bitmap]::FromFile(
    (Join-Path $sourceDir 'welcome_wordmark.png')
)
$loadingSource = [Drawing.Bitmap]::FromFile(
    (Join-Path $sourceDir 'loading_wordmark.png')
)

try {
    $iconBounds = Get-AlphaBounds $iconSource
    $iconCrop = New-CroppedBitmap $iconSource $iconBounds 18
    $iconAsset = Fit-Bitmap $iconCrop 512 512

    $welcomeBounds = Get-AlphaBounds $welcomeSource 0 600
    $welcomeCrop = New-CroppedBitmap $welcomeSource $welcomeBounds 24
    $welcomeFitted = Fit-Bitmap $welcomeCrop 1100 1100
    $welcomeAsset = New-TintedBitmap $welcomeFitted (
        [Drawing.Color]::FromArgb(255, 11, 46, 122)
    ) 32

    $loadingBounds = Get-AlphaBounds $loadingSource
    $loadingCrop = New-CroppedBitmap $loadingSource $loadingBounds 16
    $loadingFitted = Fit-Bitmap $loadingCrop 1400 1400
    $loadingAsset = New-TintedBitmap $loadingFitted (
        [Drawing.Color]::FromArgb(255, 11, 46, 122)
    ) 32

    $welcomeDark = New-TintedBitmap $welcomeAsset (
        [Drawing.Color]::FromArgb(255, 238, 244, 255)
    ) 32
    $loadingDark = New-TintedBitmap $loadingAsset (
        [Drawing.Color]::FromArgb(255, 238, 244, 255)
    ) 32

    Save-Bitmap $iconAsset (Join-Path $assetDir 'app_icon.png')
    Save-Bitmap $welcomeAsset (Join-Path $assetDir 'wordmark.png')
    Save-Bitmap $welcomeDark (Join-Path $assetDir 'wordmark_dark.png')
    Save-Bitmap $loadingAsset (Join-Path $assetDir 'loading_wordmark.png')
    Save-Bitmap $loadingDark (Join-Path $assetDir 'loading_wordmark_dark.png')

    $foregrounds = @{
        'mdpi' = 108
        'hdpi' = 162
        'xhdpi' = 216
        'xxhdpi' = 324
        'xxxhdpi' = 432
    }
    foreach ($entry in $foregrounds.GetEnumerator()) {
        $size = $entry.Value
        $canvas = New-Canvas $size $size
        $graphics = [Drawing.Graphics]::FromImage($canvas)
        try {
            $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
            $contentWidth = [int][Math]::Round($size * 0.68)
            $contentHeight = [int][Math]::Round(
                $contentWidth * $iconCrop.Height / $iconCrop.Width
            )
            $graphics.DrawImage(
                $iconCrop,
                ($size - $contentWidth) / 2,
                ($size - $contentHeight) / 2,
                $contentWidth,
                $contentHeight
            )
        }
        finally {
            $graphics.Dispose()
        }
        Save-Bitmap $canvas (
            Join-Path $resDir "mipmap-$($entry.Key)\ic_launcher_foreground.png"
        )
        $canvas.Dispose()
    }

    $legacy = @{
        'mdpi' = 48
        'hdpi' = 72
        'xhdpi' = 96
        'xxhdpi' = 144
        'xxxhdpi' = 192
    }
    foreach ($entry in $legacy.GetEnumerator()) {
        $size = $entry.Value
        $square = New-LegacyIcon $iconCrop $size $false
        $round = New-LegacyIcon $iconCrop $size $true
        Save-Bitmap $square (
            Join-Path $resDir "mipmap-$($entry.Key)\ic_launcher.png"
        )
        Save-Bitmap $round (
            Join-Path $resDir "mipmap-$($entry.Key)\ic_launcher_round.png"
        )
        $square.Dispose()
        $round.Dispose()
    }

    $splashSpecs = @(
        @{ Path = 'drawable\splash.png'; Width = 480; Height = 320; Fraction = 0.62; Night = $false },
        @{ Path = 'drawable-port-mdpi\splash.png'; Width = 320; Height = 480; Fraction = 0.76; Night = $false },
        @{ Path = 'drawable-port-hdpi\splash.png'; Width = 480; Height = 800; Fraction = 0.76; Night = $false },
        @{ Path = 'drawable-port-xhdpi\splash.png'; Width = 720; Height = 1280; Fraction = 0.76; Night = $false },
        @{ Path = 'drawable-port-xxhdpi\splash.png'; Width = 960; Height = 1600; Fraction = 0.76; Night = $false },
        @{ Path = 'drawable-port-xxxhdpi\splash.png'; Width = 1280; Height = 1920; Fraction = 0.76; Night = $false },
        @{ Path = 'drawable-land-mdpi\splash.png'; Width = 480; Height = 320; Fraction = 0.56; Night = $false },
        @{ Path = 'drawable-land-hdpi\splash.png'; Width = 800; Height = 480; Fraction = 0.56; Night = $false },
        @{ Path = 'drawable-land-xhdpi\splash.png'; Width = 1280; Height = 720; Fraction = 0.56; Night = $false },
        @{ Path = 'drawable-land-xxhdpi\splash.png'; Width = 1600; Height = 960; Fraction = 0.56; Night = $false },
        @{ Path = 'drawable-land-xxxhdpi\splash.png'; Width = 1920; Height = 1280; Fraction = 0.56; Night = $false },
        @{ Path = 'drawable-night\splash.png'; Width = 480; Height = 320; Fraction = 0.62; Night = $true },
        @{ Path = 'drawable-port-night-mdpi\splash.png'; Width = 320; Height = 480; Fraction = 0.76; Night = $true },
        @{ Path = 'drawable-port-night-hdpi\splash.png'; Width = 480; Height = 800; Fraction = 0.76; Night = $true },
        @{ Path = 'drawable-port-night-xhdpi\splash.png'; Width = 720; Height = 1280; Fraction = 0.76; Night = $true },
        @{ Path = 'drawable-port-night-xxhdpi\splash.png'; Width = 960; Height = 1600; Fraction = 0.76; Night = $true },
        @{ Path = 'drawable-port-night-xxxhdpi\splash.png'; Width = 1280; Height = 1920; Fraction = 0.76; Night = $true },
        @{ Path = 'drawable-land-night-mdpi\splash.png'; Width = 480; Height = 320; Fraction = 0.56; Night = $true },
        @{ Path = 'drawable-land-night-hdpi\splash.png'; Width = 800; Height = 480; Fraction = 0.56; Night = $true },
        @{ Path = 'drawable-land-night-xhdpi\splash.png'; Width = 1280; Height = 720; Fraction = 0.56; Night = $true },
        @{ Path = 'drawable-land-night-xxhdpi\splash.png'; Width = 1600; Height = 960; Fraction = 0.56; Night = $true },
        @{ Path = 'drawable-land-night-xxxhdpi\splash.png'; Width = 1920; Height = 1280; Fraction = 0.56; Night = $true }
    )

    foreach ($spec in $splashSpecs) {
        $tint = if ($spec.Night) { $welcomeDark } else { $welcomeAsset }
        $canvas = New-Canvas $spec.Width $spec.Height
        $graphics = [Drawing.Graphics]::FromImage($canvas)
        try {
            $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
            $logoWidth = [int][Math]::Round($spec.Width * $spec.Fraction)
            $logoHeight = [int][Math]::Round(
                $logoWidth * $tint.Height / $tint.Width
            )
            $x = ($spec.Width - $logoWidth) / 2
            $y = ($spec.Height - $logoHeight) / 2
            $graphics.DrawImage($tint, $x, $y, $logoWidth, $logoHeight)
        }
        finally {
            $graphics.Dispose()
        }
        Save-Bitmap $canvas (Join-Path $resDir $spec.Path)
        $canvas.Dispose()
    }

    foreach ($night in @($false, $true)) {
        $tint = if ($night) { $welcomeDark } else { $welcomeAsset }
        $canvas = New-Canvas 640 384
        $graphics = [Drawing.Graphics]::FromImage($canvas)
        try {
            $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $logoWidth = 560
            $logoHeight = [int][Math]::Round(
                $logoWidth * $tint.Height / $tint.Width
            )
            $graphics.DrawImage(
                $tint,
                (640 - $logoWidth) / 2,
                (384 - $logoHeight) / 2,
                $logoWidth,
                $logoHeight
            )
        }
        finally {
            $graphics.Dispose()
        }
        $path = if ($night) {
            'drawable-night\timepage_branding.png'
        } else {
            'drawable\timepage_branding.png'
        }
        Save-Bitmap $canvas (Join-Path $resDir $path)
        $canvas.Dispose()
    }

    $iconAsset.Dispose()
    $welcomeAsset.Dispose()
    $loadingAsset.Dispose()
    $welcomeDark.Dispose()
    $loadingDark.Dispose()
    $iconCrop.Dispose()
    $welcomeFitted.Dispose()
    $loadingFitted.Dispose()
    $welcomeCrop.Dispose()
    $loadingCrop.Dispose()
}
finally {
    $iconSource.Dispose()
    $welcomeSource.Dispose()
    $loadingSource.Dispose()
}

Write-Output 'Brand assets generated.'
