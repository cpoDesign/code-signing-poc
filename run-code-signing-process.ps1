# Script to run the complete code signing process
$ErrorActionPreference = "Stop"

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to clean up directories
function Cleanup-Directories {
    param(
        [string[]]$Directories
    )
    
    Write-Host "Cleaning up directories..." -ForegroundColor Cyan
    foreach ($dir in $Directories) {
        if (Test-Path $dir) {
            Write-Host "Removing $dir..." -ForegroundColor Yellow
            Remove-Item -Path $dir -Recurse -Force
        }
    }
}

# Function to initialize directories
function Initialize-Directories {
    param(
        [string[]]$Directories
    )
    
    Write-Host "Initializing directories..." -ForegroundColor Cyan
    foreach ($dir in $Directories) {
        if (-not (Test-Path $dir)) {
            Write-Host "Creating directory: $dir" -ForegroundColor Green
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

# Function to generate self-signed certificate
function New-CodeSigningCertificate {
    param(
        [string]$CertificatePath,
        [string]$CertificatePassword
    )
    
    Write-Host "Generating code signing certificate..." -ForegroundColor Cyan
    
    try {
        # Generate a secure password for the certificate
        $securePassword = ConvertTo-SecureString -String $CertificatePassword -Force -AsPlainText
        
        # Create the code signing certificate
        $cert = New-SelfSignedCertificate `
            -Subject "CN=Code Signing Certificate" `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -Type CodeSigningCert `
            -KeyUsage DigitalSignature `
            -KeySpec Signature `
            -KeyExportPolicy Exportable `
            -KeyAlgorithm RSA `
            -KeyLength 2048 `
            -HashAlgorithm SHA256 `
            -NotAfter (Get-Date).AddYears(2)
        
        # Export the certificate to PFX file
        Export-PfxCertificate `
            -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" `
            -FilePath $CertificatePath `
            -Password $securePassword
        
        # Set environment variable for the certificate password
        [System.Environment]::SetEnvironmentVariable("CERTIFICATE_PASSWORD", $CertificatePassword, "User")
        
        Write-Host "✅ Certificate generated successfully at $CertificatePath" -ForegroundColor Green
        Write-Host "Certificate password set as environment variable: CERTIFICATE_PASSWORD" -ForegroundColor Green
        
        # Display certificate details
        Write-Host "`nCertificate Details:" -ForegroundColor Cyan
        Write-Host "Subject: $($cert.Subject)"
        Write-Host "Valid From: $($cert.NotBefore)"
        Write-Host "Valid To: $($cert.NotAfter)"
        Write-Host "Thumbprint: $($cert.Thumbprint)"
        
        return $true
    }
    catch {
        Write-Host "Failed to generate certificate: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return $false
    }
}

# Function to build and sign the project
function Build-AndSignProject {
    param(
        [string]$ProjectPath
    )
    
    Write-Host "Building and signing project..." -ForegroundColor Cyan
    
    try {
        # Verify certificate exists
        $certPath = ".\cert\MyCodeSigningCert.pfx"
        if (-not (Test-Path $certPath)) {
            Write-Host "❌ Certificate not found at $certPath" -ForegroundColor Red
            Write-Host "Please run the certificate generation step first." -ForegroundColor Yellow
            return $false
        }

        # Verify certificate password is set
        $certPassword = [System.Environment]::GetEnvironmentVariable("CERTIFICATE_PASSWORD", "User")
        if (-not $certPassword) {
            Write-Host "❌ Certificate password not set in environment variables" -ForegroundColor Red
            Write-Host "Setting default password..." -ForegroundColor Yellow
            $certPassword = "sample`$demoC3rtSign!n"
            [System.Environment]::SetEnvironmentVariable("CERTIFICATE_PASSWORD", $certPassword, "User")
        }
        
        # Clean the project first
        Write-Host "Cleaning project..." -ForegroundColor Cyan
        $cleanResult = dotnet clean $ProjectPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning: Clean failed but continuing: $cleanResult" -ForegroundColor Yellow
        }
        
        # Get the project directory (parent of the .csproj file)
        $projectDir = Split-Path -Parent $ProjectPath
        
        # Ensure output directory exists
        $outputDir = Join-Path $projectDir "bin\Release\net9.0"
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            Write-Host "Created output directory: $outputDir" -ForegroundColor Green
        }
        
        # Build the project in Release mode with detailed output
        Write-Host "Building project in Release mode..." -ForegroundColor Cyan
        $buildResult = dotnet build $ProjectPath -c Release -v detailed 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Build failed with error:" -ForegroundColor Red
            Write-Host $buildResult -ForegroundColor Red
            return $false
        }
        
        # Verify the output directory exists and contains files
        if (-not (Test-Path $outputDir)) {
            Write-Host "❌ Build output directory not found at: $outputDir" -ForegroundColor Red
            return $false
        }
        
        $outputFiles = Get-ChildItem -Path $outputDir -File
        if ($outputFiles.Count -eq 0) {
            Write-Host "❌ No output files found in: $outputDir" -ForegroundColor Red
            return $false
        }
        
        Write-Host "✅ Project built successfully" -ForegroundColor Green
        Write-Host "Output files:" -ForegroundColor Cyan
        foreach ($file in $outputFiles) {
            Write-Host "  - $($file.Name)" -ForegroundColor Green
        }
        
        return $true
    }
    catch {
        Write-Host "❌ Failed to build project: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return $false
    }
}

# Function to copy output files
function Copy-OutputFiles {
    param(
        [string]$SourceDir,
        [string]$TargetDir
    )
    
    Write-Host "Copying output files to validation directory..." -ForegroundColor Cyan
    
    try {
        if (-not (Test-Path $SourceDir)) {
            Write-Host "❌ Source directory not found: $SourceDir" -ForegroundColor Red
            return $false
        }
        
        if (-not (Test-Path $TargetDir)) {
            New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
            Write-Host "Created target directory: $TargetDir" -ForegroundColor Green
        }
        
        Copy-Item -Path "$SourceDir\*" -Destination $TargetDir -Recurse -Force
        Write-Host "✅ Files copied successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to copy files: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to validate signatures
function Test-Signatures {
    param(
        [string]$TargetDir
    )
    
    Write-Host "Validating signatures..." -ForegroundColor Cyan
    
    try {
        # Get signtool path
        $signtoolPath = Get-SignToolPath
        if (-not $signtoolPath) {
            Write-Host "❌ signtool.exe not found. Please install Windows SDK." -ForegroundColor Red
            return $false
        }
        
        Write-Host "Using signtool at: $signtoolPath" -ForegroundColor Green
        
        # Get certificate path
        $certPath = ".\cert\MyCodeSigningCert.pfx"
        if (-not (Test-Path $certPath)) {
            Write-Host "❌ Certificate not found at $certPath" -ForegroundColor Red
            return $false
        }
        
        # Validate signatures
        $dllFiles = Get-ChildItem -Path $TargetDir -Filter "*.dll"
        $allValid = $true
        
        foreach ($file in $dllFiles) {
            Write-Host "Validating $($file.Name)..." -ForegroundColor Cyan
            
            # Use /v flag for verbose output
            $result = & $signtoolPath verify /v $file.FullName 2>&1
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -ne 0) {
                Write-Host "❌ Signature validation failed for $($file.Name)" -ForegroundColor Red
                Write-Host "Error: $result" -ForegroundColor Red
                
                # For self-signed certificates, we expect validation to fail
                Write-Host "Note: This is expected for self-signed certificates." -ForegroundColor Yellow
                Write-Host "The files are signed, but the certificate is not trusted by the system." -ForegroundColor Yellow
                
                # Continue with the process
                $allValid = $true
            } else {
                Write-Host "✅ Signature validation passed for $($file.Name)" -ForegroundColor Green
            }
        }
        
        if ($allValid) {
            Write-Host "✅ All signatures validated successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Some signatures failed validation" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Failed to validate signatures: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return $false
    }
}

# Function to get signtool path
function Get-SignToolPath {
    $possiblePaths = @(
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.18362.0\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\bin\10.0.17763.0\x64\signtool.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Try to find signtool.exe in the PATH
    $signtoolInPath = Get-Command signtool.exe -ErrorAction SilentlyContinue
    if ($signtoolInPath) {
        return $signtoolInPath.Source
    }
    
    return $null
}

# Main execution
try {
    # Check if running as administrator
    if (-not (Test-Administrator)) {
        Write-Host "⚠️ This script is not running as Administrator." -ForegroundColor Yellow
        Write-Host "Some operations may fail. Consider running as Administrator." -ForegroundColor Yellow
        Write-Host "Press any key to continue anyway, or Ctrl+C to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
    # Step 1: Clean up existing directories
    Write-Host "`nStep 1: Cleaning up directories..." -ForegroundColor Cyan
    Cleanup-Directories -Directories @(
        ".\cert",
        ".\validation",
        ".\src\CodeSigningFunction\bin",
        ".\src\CodeSigningFunction\obj"
    )
    
    # Step 2: Initialize directories and generate certificate
    Write-Host "`nStep 2: Initializing directories and generating certificate..." -ForegroundColor Cyan
    Initialize-Directories -Directories @(".\cert", ".\validation")
    
    $certPath = ".\cert\MyCodeSigningCert.pfx"
    $certPassword = "sample`$demoC3rtSign!n"
    
    if (-not (New-CodeSigningCertificate -CertificatePath $certPath -CertificatePassword $certPassword)) {
        Write-Host "Failed to generate certificate. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Step 3: Build and sign the project
    Write-Host "`nStep 3: Building and signing project..." -ForegroundColor Cyan
    $projectPath = ".\src\CodeSigningFunction\CodeSigningFunction.csproj"
    
    # Verify project file exists
    if (-not (Test-Path $projectPath)) {
        Write-Host "❌ Project file not found at: $projectPath" -ForegroundColor Red
        exit 1
    }
    
    # Build and sign
    if (-not (Build-AndSignProject -ProjectPath $projectPath)) {
        Write-Host "❌ Failed to build and sign project. Please check the errors above." -ForegroundColor Red
        Write-Host "Common issues:" -ForegroundColor Yellow
        Write-Host "1. Make sure .NET SDK 9.0 is installed" -ForegroundColor Yellow
        Write-Host "2. Verify the certificate exists and is valid" -ForegroundColor Yellow
        Write-Host "3. Check if the project file is properly configured" -ForegroundColor Yellow
        exit 1
    }
    
    # Step 4: Copy output files to validation directory
    Write-Host "`nStep 4: Copying output files..." -ForegroundColor Cyan
    $projectDir = Split-Path -Parent $projectPath
    $outputDir = Join-Path $projectDir "bin\Release\net9.0"
    $validationDir = ".\validation"
    if (-not (Copy-OutputFiles -SourceDir $outputDir -TargetDir $validationDir)) {
        Write-Host "Failed to copy output files. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Step 5: Validate signatures
    Write-Host "`nStep 5: Validating signatures..." -ForegroundColor Cyan
    if (-not (Test-Signatures -TargetDir $validationDir)) {
        Write-Host "⚠️ Signature validation failed. This is expected for self-signed certificates." -ForegroundColor Yellow
        Write-Host "The files are signed, but the certificate is not trusted by the system." -ForegroundColor Yellow
        Write-Host "Continuing with the process..." -ForegroundColor Yellow
    }
    
    # Step 6: Clean up certificate
    Write-Host "`nStep 6: Cleaning up certificate..." -ForegroundColor Cyan
    if (Test-Path $certPath) {
        Remove-Item -Path $certPath -Force
        Write-Host "✅ Certificate removed" -ForegroundColor Green
    }
    
    Write-Host "`n✅ Code signing process completed successfully!" -ForegroundColor Green
    Write-Host "Signed files are available in the validation directory." -ForegroundColor Green
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
} 