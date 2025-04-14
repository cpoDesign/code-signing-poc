# Code Signing Process

This repository contains scripts and tools for signing .NET assemblies with a code signing certificate. The process includes generating a self-signed certificate, building a .NET project, signing the assemblies, and validating the signatures.

## Overview

Code signing is a process of digitally signing executables and scripts to confirm the software's author and guarantee that the code has not been altered or corrupted since it was signed. This is important for:

- Verifying the authenticity of software
- Ensuring code integrity
- Meeting security requirements
- Building trust with users

## Prerequisites

- Windows 10 or later
- PowerShell 5.1 or later
- .NET SDK 9.0 or later
- Windows SDK (for signtool.exe)

## Project Structure

```
signing-code/
├── cert/                  # Directory for storing certificates
├── validation/            # Directory for storing signed files
├── src/
│   └── CodeSigningFunction/  # Sample .NET project to be signed
├── run-code-signing-process.ps1  # Main script to run the signing process
└── README.md              # This file
```

## How It Works

The code signing process consists of the following steps:

1. **Clean up directories**: Remove any existing certificates, validation files, and build outputs.
2. **Generate a self-signed certificate**: Create a code signing certificate for signing the assemblies.
3. **Build the project**: Compile the .NET project in Release mode.
4. **Sign the assemblies**: Sign the compiled DLLs with the generated certificate.
5. **Validate signatures**: Verify that the assemblies were signed correctly.
6. **Clean up**: Remove the certificate after signing is complete.

### Certificate Generation

The script uses PowerShell's `New-SelfSignedCertificate` cmdlet to create a code signing certificate with the following properties:

- Subject: "CN=Code Signing Certificate"
- Type: CodeSigningCert
- Key Usage: DigitalSignature
- Key Algorithm: RSA
- Key Length: 2048 bits
- Hash Algorithm: SHA256
- Validity: 2 years

The certificate is exported to a PFX file with a password and stored in the `cert` directory.

### Project Configuration

The .NET project is configured to sign assemblies during the build process using the following settings in the project file:

```xml
<PropertyGroup>
  <SignOutputAssemblies>true</SignOutputAssemblies>
  <CertificatePath>$(MSBuildProjectDirectory)\..\..\cert\MyCodeSigningCert.pfx</CertificatePath>
  <CertificatePassword>$(CERTIFICATE_PASSWORD)</CertificatePassword>
  <SignToolPath>C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe</SignToolPath>
  <SignToolTimestampDigestAlgorithm>sha256</SignToolTimestampDigestAlgorithm>
  <SignToolTimestampUrl>http://timestamp.digicert.com</SignToolTimestampUrl>
  <SignToolFileDigestAlgorithm>sha256</SignToolFileDigestAlgorithm>
</PropertyGroup>
```

The project uses a custom target to sign the assemblies after the build:

```xml
<Target Name="SignOutputAssemblies" AfterTargets="AfterBuild" Condition="'$(Configuration)' == 'Release'">
  <PropertyGroup>
    <AssemblyToSign>$(TargetPath)</AssemblyToSign>
  </PropertyGroup>
  <Message Text="Signing $(AssemblyToSign) with certificate $(CertificatePath)" Importance="high" />
  <Exec Command="&quot;$(SignToolPath)&quot; sign /f &quot;$(CertificatePath)&quot; /p &quot;$(CertificatePassword)&quot; /tr &quot;$(SignToolTimestampUrl)&quot; /td sha256 /fd sha256 /a &quot;$(AssemblyToSign)&quot;" />
</Target>
```

### Signing Process

The signing process uses the Windows SDK's `signtool.exe` utility with the following parameters:

- `/f`: Specifies the certificate file
- `/p`: Specifies the certificate password
- `/tr`: Specifies the timestamp server URL
- `/td`: Specifies the timestamp digest algorithm (SHA256)
- `/fd`: Specifies the file digest algorithm (SHA256)
- `/a`: Automatically selects the best certificate

### Signature Validation

The script validates the signatures using `signtool.exe` with the `/v` flag for verbose output. For self-signed certificates, validation may fail because the certificate is not trusted by the system, but this is expected and doesn't indicate a problem with the signing process.

## Running the Process

To run the code signing process, execute the following command in PowerShell:

```powershell
.\run-code-signing-process.ps1
```

The script will:
1. Clean up existing directories
2. Generate a new certificate
3. Build and sign the project
4. Copy the signed files to the validation directory
5. Validate the signatures
6. Clean up the certificate

## Troubleshooting

### Common Issues

1. **Certificate not found**: Make sure the certificate was generated successfully.
2. **Build failures**: Ensure .NET SDK 9.0 is installed and the project file is properly configured.
3. **SignTool not found**: Install the Windows SDK and ensure signtool.exe is in the expected location.
4. **Signature validation failures**: This is expected for self-signed certificates. The files are signed, but the certificate is not trusted by the system.

### Running as Administrator

Some operations may require administrator privileges. If you encounter permission issues, run PowerShell as Administrator.

## Security Considerations

- The self-signed certificate used in this process is for demonstration purposes only.
- In a production environment, use a certificate from a trusted Certificate Authority.
- Keep the certificate password secure and never commit it to source control.
- Consider using a hardware security module (HSM) for storing the certificate in a production environment.

## Additional Resources

- [Microsoft Docs: Code Signing](https://docs.microsoft.com/en-us/windows/win32/seccrypto/code-signing)
- [Microsoft Docs: SignTool](https://docs.microsoft.com/en-us/windows/win32/seccrypto/signtool)
- [Microsoft Docs: New-SelfSignedCertificate](https://docs.microsoft.com/en-us/powershell/module/pkiclient/new-selfsignedcertificate)

## License

MIT
