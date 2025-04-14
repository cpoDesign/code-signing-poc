# Script to manually sign DLLs
$ErrorActionPreference = "Stop"

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to get signtool path
function Get-SignToolPath {
    $signtoolPaths = @(
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe"
    )
    
    foreach ($path in $signtoolPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

# Main execution
Write-Host "=== Manual DLL Signing ===" -ForegroundColor Cyan
Write-Host "This script will manually sign DLLs using signtool." -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-Host "❌ This script must be run as Administrator." -ForegroundColor Red
    Write-Host "   Please right-click on PowerShell and select 'Run as Administrator'." -ForegroundColor Yellow
    exit 1
}

# Get signtool path
$signtoolPath = Get-SignToolPath
if (-not $signtoolPath) {
    Write-Host "❌ signtool.exe not found. Please install Windows SDK." -ForegroundColor Red
    exit 1
}

Write-Host "Using signtool at: $signtoolPath" -ForegroundColor Green

# Get certificate path
$certPath = ".\cert\MyCodeSigningCert.pfx"
if (-not (Test-Path $certPath)) {
    Write-Host "❌ Certificate not found at $certPath" -ForegroundColor Red
    exit 1
}

# Get certificate password
$certPassword = [System.Environment]::GetEnvironmentVariable("CERTIFICATE_PASSWORD", "User")
if (-not $certPassword) {
    $certPassword = "sample`$demoC3rtSign!n"
    Write-Host "⚠️ Certificate password not found in environment variables. Using default password." -ForegroundColor Yellow
}

# Get DLLs to sign
$dllPath = Read-Host "Enter the path to the DLLs to sign (default: .\validation)"
if (-not $dllPath) {
    $dllPath = ".\validation"
}

if (-not (Test-Path $dllPath)) {
    Write-Host "❌ Path not found: $dllPath" -ForegroundColor Red
    exit 1
}

# Get DLL files
$dllFiles = Get-ChildItem -Path $dllPath -Filter "*.dll"
if ($dllFiles.Count -eq 0) {
    Write-Host "❌ No DLL files found in $dllPath" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($dllFiles.Count) DLL files to sign." -ForegroundColor Green

# Sign each DLL
$allSigned = $true
foreach ($file in $dllFiles) {
    Write-Host "Signing $($file.Name)..." -ForegroundColor Cyan
    
    # Sign the file
    $result = & $signtoolPath sign /f $certPath /p $certPassword /tr http://timestamp.digicert.com /td sha256 /fd sha256 $file.FullName 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Successfully signed $($file.Name)" -ForegroundColor Green
        
        # Verify the signature
        $verifyResult = & $signtoolPath verify /pa $file.FullName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Signature verification passed for $($file.Name)" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Signature verification failed for $($file.Name)" -ForegroundColor Yellow
            Write-Host "Verification error: $verifyResult" -ForegroundColor Yellow
            $allSigned = $false
        }
    } else {
        Write-Host "❌ Failed to sign $($file.Name): $result" -ForegroundColor Red
        $allSigned = $false
    }
}

# Summary
if ($allSigned) {
    Write-Host "`n✅ All DLLs signed successfully." -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Some DLLs failed to sign or verify." -ForegroundColor Yellow
    Write-Host "   Please check the error messages above." -ForegroundColor Yellow
} 