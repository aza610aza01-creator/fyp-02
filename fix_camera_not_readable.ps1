[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$EnableWindowsCameraPrivacy,
    [switch]$RunFlutterChecks
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$requiredFiles = @(
    'pubspec.yaml',
    'lib\services\camera_detection_service.dart',
    'lib\screens\camera_detection\camera_detection_screen.dart'
)

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "This script must be kept in the Flutter project root. Missing: $relativePath"
    }
}

Set-Location -LiteralPath $projectRoot
Write-Host "Checking camera setup in $projectRoot" -ForegroundColor Cyan

$cameraService = Get-Content -LiteralPath (Join-Path $projectRoot 'lib\services\camera_detection_service.dart') -Raw
if ($cameraService -notmatch 'availableCameras\(\)') {
    throw 'The camera service does not use Flutter camera discovery. No source files were changed.'
}
if ($cameraService -match 'Pose model unavailable.{0,80}(?:Active|Ready)') {
    throw 'The camera service contains a misleading pose-model status. Remove that source edit before continuing.'
}
Write-Host '[OK] Flutter camera discovery is present; this script will not invent detections or modify camera logic.' -ForegroundColor Green

$headersPath = Join-Path $projectRoot 'web\_headers'
function Save-WebHeaders {
    param([System.Collections.Generic.List[string]]$Lines)
    [System.IO.File]::WriteAllLines(
        $headersPath,
        $Lines.ToArray(),
        [System.Text.UTF8Encoding]::new($false)
    )
}

if (-not (Test-Path -LiteralPath $headersPath -PathType Leaf)) {
    $headerLines = [System.Collections.Generic.List[string]]::new()
    $headerLines.Add('/*')
    $headerLines.Add('  Permissions-Policy: camera=(self)')
    Save-WebHeaders -Lines $headerLines
    Write-Host '[UPDATED] Created web\_headers with same-origin camera permission.' -ForegroundColor Green
} else {
    $headerLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in Get-Content -LiteralPath $headersPath -Encoding UTF8) {
        $headerLines.Add($line)
    }

    $wildcardBlockIndex = -1
    $wildcardPolicyIndex = -1
    for ($index = 0; $index -lt $headerLines.Count; $index++) {
        if ($headerLines[$index] -match '^\s*/\*\s*$') {
            $wildcardBlockIndex = $index
            $wildcardPolicyIndex = -1
            continue
        }
        if ($wildcardBlockIndex -ge 0 -and
            $headerLines[$index] -match '^\s*\S') {
            if ($headerLines[$index] -match '^\s*Permissions-Policy\s*:') {
                $wildcardPolicyIndex = $index
            }
            if ($headerLines[$index] -notmatch '^\s') {
                $wildcardBlockIndex = -1
            }
        }
    }

    if ($wildcardBlockIndex -ge 0 -and $wildcardPolicyIndex -ge 0) {
        $policyLine = $headerLines[$wildcardPolicyIndex]
        if ($policyLine -match '(?i)\bcamera\s*=') {
            $updatedPolicy = [regex]::Replace(
                $policyLine,
                '(?i)\bcamera\s*=\s*(?:\([^)]*\)|\*)',
                'camera=(self)'
            )
            $headerLines[$wildcardPolicyIndex] = $updatedPolicy
        } else {
            $headerLines[$wildcardPolicyIndex] = $policyLine.TrimEnd() + ', camera=(self)'
        }
        Save-WebHeaders -Lines $headerLines
        Write-Host '[UPDATED] Restricted the web camera policy to this site (camera=(self)).' -ForegroundColor Green
    } elseif ($wildcardBlockIndex -ge 0) {
        $headerLines.Insert($wildcardBlockIndex + 1, '  Permissions-Policy: camera=(self)')
        Save-WebHeaders -Lines $headerLines
        Write-Host '[UPDATED] Added same-origin camera permission to the web headers.' -ForegroundColor Green
    } else {
        $headerLines.Add('/*')
        $headerLines.Add('  Permissions-Policy: camera=(self)')
        Save-WebHeaders -Lines $headerLines
        Write-Host '[UPDATED] Added a same-origin camera policy for all web routes.' -ForegroundColor Green
    }
}

$manifestPath = Join-Path $projectRoot 'android\app\src\main\AndroidManifest.xml'
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    [xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
    $namespaceManager = [System.Xml.XmlNamespaceManager]::new($manifest.NameTable)
    $namespaceManager.AddNamespace('android', 'http://schemas.android.com/apk/res/android')
    $cameraPermission = $manifest.SelectSingleNode(
        '/manifest/uses-permission[@android:name="android.permission.CAMERA"]',
        $namespaceManager
    )
    if (-not $cameraPermission) {
        Write-Warning 'AndroidManifest.xml is missing android.permission.CAMERA. Add it before building for Android.'
    } else {
        Write-Host '[OK] Android camera permission is declared.' -ForegroundColor Green
    }
}

$iosInfoPath = Join-Path $projectRoot 'ios\Runner\Info.plist'
if (Test-Path -LiteralPath $iosInfoPath -PathType Leaf) {
    $iosInfo = Get-Content -LiteralPath $iosInfoPath -Raw
    if ($iosInfo -notmatch '<key>NSCameraUsageDescription</key>') {
        Write-Warning 'iOS Info.plist is missing NSCameraUsageDescription.'
    } else {
        Write-Host '[OK] iOS camera usage description is present.' -ForegroundColor Green
    }
}

$macInfoPath = Join-Path $projectRoot 'macos\Runner\Info.plist'
if (Test-Path -LiteralPath $macInfoPath -PathType Leaf) {
    $macInfo = Get-Content -LiteralPath $macInfoPath -Raw
    if ($macInfo -notmatch '<key>NSCameraUsageDescription</key>') {
        Write-Warning 'macOS Info.plist is missing NSCameraUsageDescription.'
    } else {
        Write-Host '[OK] macOS camera usage description is present.' -ForegroundColor Green
    }
}

if ($EnableWindowsCameraPrivacy) {
    $privacyUpdated = $false
    $privacyKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\NonPackaged'
    )
    foreach ($key in $privacyKeys) {
        if ($PSCmdlet.ShouldProcess($key, 'Allow Windows camera access for this user')) {
            New-Item -Path $key -Force | Out-Null
            Set-ItemProperty -Path $key -Name Value -Value Allow -Type String
            $privacyUpdated = $true
        }
    }
    if ($privacyUpdated) {
        Write-Host 'Windows camera privacy was enabled for this user. Restart the browser or app before retrying.' -ForegroundColor Green
    } else {
        Write-Host 'No Windows camera privacy changes were made.' -ForegroundColor DarkGray
    }
} else {
    Write-Host 'Windows camera privacy was not changed. Use -EnableWindowsCameraPrivacy to opt in.' -ForegroundColor DarkGray
}

if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
    $cameras = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Class -in @('Camera', 'Image') -or
            $_.FriendlyName -match '(?i)camera|webcam'
        })
    if ($cameras.Count -eq 0) {
        Write-Warning 'Windows did not report a connected camera device. Check the camera cable, device switch, or Device Manager.'
    } else {
        Write-Host 'Windows camera devices:' -ForegroundColor Cyan
        $cameras | Select-Object Status, Class, FriendlyName | Format-Table -AutoSize
        $unavailable = @($cameras | Where-Object { $_.Status -ne 'OK' })
        if ($unavailable.Count -gt 0) {
            Write-Warning 'One or more camera devices are not ready. Check their status in Windows Device Manager.'
        }
    }
} else {
    Write-Warning 'Get-PnpDevice is unavailable; camera hardware status could not be checked.'
}

Write-Host ''
Write-Host 'If the browser reports cameraNotReadable:' -ForegroundColor Yellow
Write-Host '  1. Close video-call apps and other browser tabs that may own the camera.'
Write-Host '  2. In Windows Settings > Privacy & security > Camera, allow camera and desktop-app access.'
Write-Host '  3. Open the site over HTTPS or localhost, allow camera access in the browser, then retry.'
Write-Host 'A script cannot release a camera held by another application or override browser permission.' -ForegroundColor DarkGray

if ($RunFlutterChecks) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        throw 'Flutter was not found on PATH. Install Flutter or run flutter analyze and flutter test manually.'
    }
    & flutter analyze lib\services\camera_detection_service.dart lib\screens\camera_detection\camera_detection_screen.dart test\camera_detection_test.dart
    if ($LASTEXITCODE -ne 0) {
        throw "flutter analyze failed with exit code $LASTEXITCODE"
    }
    & flutter test test\camera_detection_test.dart
    if ($LASTEXITCODE -ne 0) {
        throw "Camera detection tests failed with exit code $LASTEXITCODE"
    }
}
