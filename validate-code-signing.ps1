param(
    [Parameter(Mandatory=$false)]
    [string]$CertificatePassword = "sample`$demoC3rtSign!n",
    [Parameter(Mandatory=$false)]
    [switch]$SkipCertificateCreation = $false
)

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

# Function to find signtool.exe
function Get-SignToolPath {
    $sdkPaths = @(
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe"
    )
    
    foreach ($path in $sdkPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return $null
}

# Function to update project file with correct signtool path
function Update-ProjectFile {
    param(
        [string]$SignToolPath
    )
    
    $projectFile = ".\src\CodeSigningFunction\CodeSigningFunction.csproj"
    if (-not (Test-Path $projectFile)) {
        Write-Host "Project file not found at $projectFile" -ForegroundColor Red
        return $false
    }
    
    $content = Get-Content -Path $projectFile -Raw
    $updatedContent = $content -replace '<SignToolPath>.*</SignToolPath>', "<SignToolPath>$SignToolPath</SignToolPath>"
    
    Set-Content -Path $projectFile -Value $updatedContent
    Write-Host "Updated project file with signtool path: $SignToolPath" -ForegroundColor Green
    return $true
}

# Function to validate signatures
function Test-AssemblySignatures {
    param(
        [string]$TargetFolder = ".\src\CodeSigningFunction\bin\Release\net8.0"
    )
    
    if (-not (Test-Path $TargetFolder)) {
        Write-Host "Output folder not found: $TargetFolder" -ForegroundColor Red
        return $false
    }
    
    Write-Host "Validating code signatures in folder: $TargetFolder" -ForegroundColor Cyan
    
    $files = Get-ChildItem -Path $TargetFolder -Recurse -Include *.dll, *.exe
    if ($files.Count -eq 0) {
        Write-Host "No assemblies found in $TargetFolder" -ForegroundColor Red
        return $false
    }
    
    $hasErrors = $false
    
    foreach ($file in $files) {
        Write-Host "`nChecking $($file.Name)..." -ForegroundColor Cyan
        $result = Get-AuthenticodeSignature -FilePath $file.FullName
        
        switch ($result.Status) {
            'Valid' {
                Write-Host "✅ $($file.Name) is signed and valid" -ForegroundColor Green
            }
            'NotSigned' {
                Write-Host "❌ $($file.Name) is not signed" -ForegroundColor Red
                $hasErrors = $true
            }
            'HashMismatch' {
                Write-Host "❌ $($file.Name) has a hash mismatch" -ForegroundColor Red
                $hasErrors = $true
            }
            default {
                Write-Host "❌ $($file.Name) is not valid: $($result.Status)" -ForegroundColor Red
                $hasErrors = $true
            }
        }
    }
    
    if ($hasErrors) {
        Write-Host "`n❌ Some files failed validation. Please check the errors above." -ForegroundColor Red
        return $false
    } else {
        Write-Host "`n✅ All files are properly signed and valid." -ForegroundColor Green
        return $true
    }
}

# Main execution
Write-Host "=== Code Signing Validation Script ===" -ForegroundColor Cyan
Write-Host "This script will validate the entire code signing process." -ForegroundColor Cyan
Write-Host ""

# Step 1: Check prerequisites
Write-Host "Step 1: Checking prerequisites..." -ForegroundColor Cyan

# Check .NET SDK
if (-not (Test-CommandExists "dotnet")) {
    Write-Host "❌ .NET SDK not found. Please install .NET 8 SDK." -ForegroundColor Red
    exit 1
}
Write-Host "✅ .NET SDK found" -ForegroundColor Green

# Check Windows SDK
$signToolPath = Get-SignToolPath
if (-not $signToolPath) {
    Write-Host "❌ Windows SDK not found. Please install Windows SDK." -ForegroundColor Red
    exit 1
}
Write-Host "✅ Windows SDK found at $signToolPath" -ForegroundColor Green

# Update project file with correct signtool path
if (-not (Update-ProjectFile -SignToolPath $signToolPath)) {
    Write-Host "❌ Failed to update project file with signtool path." -ForegroundColor Red
    exit 1
}

# Step 2: Create certificate if needed
Write-Host "`nStep 2: Setting up certificate..." -ForegroundColor Cyan
if (-not $SkipCertificateCreation) {
    # Run the certificate creation script
    & .\create-certificate.ps1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create certificate." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Skipping certificate creation as requested." -ForegroundColor Yellow
}

# Step 3: Set environment variable for certificate password
Write-Host "`nStep 3: Setting up environment..." -ForegroundColor Cyan
$env:CERTIFICATE_PASSWORD = $CertificatePassword
Write-Host "✅ Set CERTIFICATE_PASSWORD environment variable" -ForegroundColor Green

# Step 4: Build the project
Write-Host "`nStep 4: Building project..." -ForegroundColor Cyan
Push-Location .\src\CodeSigningFunction
$buildResult = dotnet build -c Release
Pop-Location

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed. Check the error messages above." -ForegroundColor Red
    exit 1
}
Write-Host "✅ Build completed successfully" -ForegroundColor Green

# Step 5: Validate signatures
Write-Host "`nStep 5: Validating signatures..." -ForegroundColor Cyan
$validationResult = Test-AssemblySignatures -TargetFolder ".\src\CodeSigningFunction\bin\Release\net8.0"

if (-not $validationResult) {
    Write-Host "❌ Signature validation failed." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Code Signing Validation Complete ===" -ForegroundColor Green
Write-Host "✅ All steps completed successfully!" -ForegroundColor Green
Write-Host "✅ Certificate is properly set up" -ForegroundColor Green
Write-Host "✅ Project builds successfully" -ForegroundColor Green
Write-Host "✅ All assemblies are properly signed" -ForegroundColor Green 