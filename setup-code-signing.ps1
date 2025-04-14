# Script to set up code signing environment
$ErrorActionPreference = "Stop"

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to create certificate directory
function Initialize-CertificateDirectory {
    $certDir = ".\cert"
    if (-not (Test-Path -Path $certDir)) {
        New-Item -ItemType Directory -Path $certDir | Out-Null
        Write-Host "Created certificate directory: $certDir" -ForegroundColor Green
    }
    return $certDir
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
        
        # Create the certificate
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
        # Build the project in Release mode
        dotnet build $ProjectPath -c Release
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to build project" -ForegroundColor Red
            return $false
        }
        
        Write-Host "✅ Project built successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to build project: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host "=== Code Signing Setup ===" -ForegroundColor Cyan
Write-Host "This script will set up your code signing environment." -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-Host "❌ This script must be run as Administrator." -ForegroundColor Red
    Write-Host "   Please right-click on PowerShell and select 'Run as Administrator'." -ForegroundColor Yellow
    exit 1
}

# Initialize certificate directory
$certDir = Initialize-CertificateDirectory
$certPath = Join-Path $certDir "MyCodeSigningCert.pfx"
$certPassword = "sample`$demoC3rtSign!n"

# Check if certificate already exists
if (Test-Path -Path $certPath) {
    Write-Host "Certificate already exists at $certPath" -ForegroundColor Yellow
    Write-Host "Do you want to overwrite it? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -ne "Y") {
        Write-Host "Operation cancelled." -ForegroundColor Red
        exit 1
    }
}

# Generate certificate
if (-not (New-CodeSigningCertificate -CertificatePath $certPath -CertificatePassword $certPassword)) {
    Write-Host "Failed to generate certificate. Exiting." -ForegroundColor Red
    exit 1
}

# Build and sign the project
$projectPath = ".\src\CodeSigningFunction\CodeSigningFunction.csproj"
if (-not (Build-AndSignProject -ProjectPath $projectPath)) {
    Write-Host "Failed to build and sign project. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "✅ Code signing environment is ready." -ForegroundColor Green
Write-Host "✅ Certificate is stored at: $certPath" -ForegroundColor Green
Write-Host "✅ Project has been built and signed." -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Run .\validate-signature.ps1 to verify the signatures" -ForegroundColor Yellow
Write-Host "2. Run .\diagnose-code-signing.ps1 to check the setup" -ForegroundColor Yellow 