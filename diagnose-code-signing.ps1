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
    if ($dotnetVersion -match "^[89]\.") {
        return $true
    }
    return $false
}

# Function to check if certificate exists
function Test-CertificateExists {
    $certPath = ".\cert\MyCodeSigningCert.pfx"
    return (Test-Path -Path $certPath)
}

# Function to check if project file is properly configured
function Test-ProjectFileConfigured {
    $projectFile = ".\src\CodeSigningFunction\CodeSigningFunction.csproj"
    if (-not (Test-Path -Path $projectFile)) {
        return $false
    }
    
    $content = Get-Content -Path $projectFile -Raw
    return ($content -match "SignOutputAssemblies" -and $content -match "CertificatePath" -and $content -match "CertificatePassword" -and $content -match "SignToolPath")
}

# Function to check if environment variable is set
function Test-EnvironmentVariableSet {
    param(
        [string]$VariableName
    )
    
    return [System.Environment]::GetEnvironmentVariable($VariableName) -ne $null
}

# Main execution
Write-Host "=== Code Signing Diagnostic Script ===" -ForegroundColor Cyan
Write-Host "This script will diagnose issues with the code signing setup." -ForegroundColor Cyan
Write-Host ""

$allChecksPassed = $true

# Check .NET SDK
Write-Host "Checking .NET SDK..." -ForegroundColor Cyan
if (Test-DotNetSDKInstalled) {
    $dotnetVersion = dotnet --version
    Write-Host "✅ .NET SDK $dotnetVersion is installed" -ForegroundColor Green
} else {
    Write-Host "❌ .NET 8.0 or 9.0 SDK is not installed" -ForegroundColor Red
    Write-Host "   Please install .NET 8.0 or 9.0 SDK from: https://dotnet.microsoft.com/download" -ForegroundColor Yellow
    $allChecksPassed = $false
}

# Check Windows SDK
Write-Host "`nChecking Windows SDK..." -ForegroundColor Cyan
if (Test-WindowsSDKInstalled) {
    Write-Host "✅ Windows SDK is installed" -ForegroundColor Green
} else {
    Write-Host "❌ Windows SDK is not installed" -ForegroundColor Red
    Write-Host "   Please install Windows SDK from: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/" -ForegroundColor Yellow
    Write-Host "   Make sure to select the 'Windows SDK for Windows Store Apps' component during installation" -ForegroundColor Yellow
    $allChecksPassed = $false
}

# Check certificate
Write-Host "`nChecking certificate..." -ForegroundColor Cyan
if (Test-CertificateExists) {
    Write-Host "✅ Certificate exists at .\cert\MyCodeSigningCert.pfx" -ForegroundColor Green
} else {
    Write-Host "❌ Certificate not found at .\cert\MyCodeSigningCert.pfx" -ForegroundColor Red
    Write-Host "   Please run .\create-certificate.ps1 to create a certificate" -ForegroundColor Yellow
    $allChecksPassed = $false
}

# Check project file
Write-Host "`nChecking project file..." -ForegroundColor Cyan
if (Test-ProjectFileConfigured) {
    Write-Host "✅ Project file is properly configured for code signing" -ForegroundColor Green
} else {
    Write-Host "❌ Project file is not properly configured for code signing" -ForegroundColor Red
    Write-Host "   Please check the project file at .\src\CodeSigningFunction\CodeSigningFunction.csproj" -ForegroundColor Yellow
    $allChecksPassed = $false
}

# Check environment variable
Write-Host "`nChecking environment variable..." -ForegroundColor Cyan
if (Test-EnvironmentVariableSet -VariableName "CERTIFICATE_PASSWORD") {
    Write-Host "✅ CERTIFICATE_PASSWORD environment variable is set" -ForegroundColor Green
} else {
    Write-Host "❌ CERTIFICATE_PASSWORD environment variable is not set" -ForegroundColor Red
    Write-Host "   Please set the environment variable: $env:CERTIFICATE_PASSWORD = 'sample`$demoC3rtSign!n'" -ForegroundColor Yellow
    $allChecksPassed = $false
}

# Summary
Write-Host "`n=== Diagnostic Summary ===" -ForegroundColor Cyan
if ($allChecksPassed) {
    Write-Host "✅ All checks passed. Code signing should work correctly." -ForegroundColor Green
    Write-Host "   Try running .\setup-code-signing.ps1 again." -ForegroundColor Green
} else {
    Write-Host "❌ Some checks failed. Please fix the issues above." -ForegroundColor Red
    Write-Host "   After fixing the issues, run this script again to verify." -ForegroundColor Yellow
    exit 1
} 