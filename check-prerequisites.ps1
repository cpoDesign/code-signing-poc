# Function to check if a command exists
function Test-CommandExists {
    param($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if (Get-Command $command) { return $true }
    } catch {
        return $false
    } finally {
        $ErrorActionPreference = $oldPreference
    }
}

# Function to check if Windows SDK is installed
function Test-WindowsSDKInstalled {
    $sdkPaths = @(
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe"
    )
    
    foreach ($path in $sdkPaths) {
        if (Test-Path $path) {
            return $true
        }
    }
    return $false
}

# Function to check if .NET SDK is installed
function Test-DotNetSDKInstalled {
    if (-not (Test-CommandExists "dotnet")) {
        return $false
    }
    
    $dotnetVersion = dotnet --version
    if ($dotnetVersion -match "^8\.") {
        return $true
    }
    return $false
}

# Main execution
Write-Host "=== Prerequisites Check ===" -ForegroundColor Cyan
Write-Host "This script will check if all required prerequisites are installed." -ForegroundColor Cyan
Write-Host ""

$allPrerequisitesMet = $true

# Check .NET SDK
Write-Host "Checking .NET SDK..." -ForegroundColor Cyan
if (Test-DotNetSDKInstalled) {
    $dotnetVersion = dotnet --version
    Write-Host "✅ .NET SDK $dotnetVersion is installed" -ForegroundColor Green
} else {
    Write-Host "❌ .NET 8 SDK is not installed" -ForegroundColor Red
    Write-Host "   Please install .NET 8 SDK from: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Yellow
    $allPrerequisitesMet = $false
}

# Check Windows SDK
Write-Host "`nChecking Windows SDK..." -ForegroundColor Cyan
if (Test-WindowsSDKInstalled) {
    Write-Host "✅ Windows SDK is installed" -ForegroundColor Green
} else {
    Write-Host "❌ Windows SDK is not installed" -ForegroundColor Red
    Write-Host "   Please install Windows SDK from: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/" -ForegroundColor Yellow
    Write-Host "   Make sure to select the 'Windows SDK for Windows Store Apps' component during installation" -ForegroundColor Yellow
    $allPrerequisitesMet = $false
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($allPrerequisitesMet) {
    Write-Host "✅ All prerequisites are installed. You can proceed with code signing." -ForegroundColor Green
} else {
    Write-Host "❌ Some prerequisites are missing. Please install them before proceeding." -ForegroundColor Red
    Write-Host "   After installing the prerequisites, run this script again to verify." -ForegroundColor Yellow
    exit 1
} 