# Script to create a self-signed certificate for code signing
$ErrorActionPreference = "Stop"

# Certificate details
$certificateName = "MyCodeSigningCert"
$certificatePath = ".\cert\MyCodeSigningCert.pfx"
$certificatePassword = "sample`$demoC3rtSign!n"
$certificateSubject = "CN=My Code Signing Certificate"
$certificateIssuer = "CN=My Code Signing Certificate"
$certificateValidDays = 365

# Create cert directory if it doesn't exist
if (-not (Test-Path -Path ".\cert")) {
    New-Item -ItemType Directory -Path ".\cert" | Out-Null
    Write-Host "Created certificate directory: .\cert" -ForegroundColor Green
}

# Check if certificate already exists
if (Test-Path -Path $certificatePath) {
    Write-Host "Certificate already exists at $certificatePath" -ForegroundColor Yellow
    Write-Host "Do you want to overwrite it? (Y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -ne "Y") {
        Write-Host "Operation cancelled." -ForegroundColor Red
        exit 1
    }
}

# Create the certificate
try {
    Write-Host "Creating self-signed certificate..." -ForegroundColor Cyan
    
    # Generate a random password for the temporary certificate
    $tempPassword = ConvertTo-SecureString -String $certificatePassword -Force -AsPlainText
    
    # Create the certificate
    $cert = New-SelfSignedCertificate `
        -Subject $certificateSubject `
        -Issuer $certificateIssuer `
        -Type CodeSigningCert `
        -KeyUsage DigitalSignature `
        -KeySpec Signature `
        -KeyExportPolicy Exportable `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddDays($certificateValidDays) `
        -CertStoreLocation "Cert:\CurrentUser\My"
    
    # Export the certificate to a PFX file
    Export-PfxCertificate `
        -Cert "Cert:\CurrentUser\My\$($cert.Thumbprint)" `
        -FilePath $certificatePath `
        -Password $tempPassword
    
    # Set the environment variable
    [System.Environment]::SetEnvironmentVariable("CERTIFICATE_PASSWORD", $certificatePassword, "User")
    
    Write-Host "Certificate created successfully at $certificatePath" -ForegroundColor Green
    Write-Host "Certificate password set as environment variable: CERTIFICATE_PASSWORD" -ForegroundColor Green
    Write-Host "Certificate will be valid for $certificateValidDays days" -ForegroundColor Green
    
    # Display certificate details
    Write-Host "`nCertificate Details:" -ForegroundColor Cyan
    Write-Host "Subject: $($cert.Subject)"
    Write-Host "Issuer: $($cert.Issuer)"
    Write-Host "Valid From: $($cert.NotBefore)"
    Write-Host "Valid To: $($cert.NotAfter)"
    Write-Host "Thumbprint: $($cert.Thumbprint)"
    
} catch {
    Write-Host "Error creating certificate: $_" -ForegroundColor Red
    exit 1
} 