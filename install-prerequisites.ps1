# Function to check if running as administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to download a file
function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    Write-Host "Downloading $Url to $OutputPath..." -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        if (Test-Path $OutputPath) {
            return $true
        }
        return $false
    } catch {
        Write-Host ("Failed to download " + $Url + " - " + $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

# Function to check if .NET SDK is installed
function Test-DotNetSDKInstalled {
    if (-not (Get-Command "dotnet" -ErrorAction SilentlyContinue)) {
        return $false
    }
    
    $dotnetVersion = dotnet --version
    if ($dotnetVersion -match "^9\.") {
        return $true
    }
    return $false
}

# Function to install .NET SDK
function Install-DotNetSDK {
    # Check if .NET 9.0 is already installed
    if (Test-DotNetSDKInstalled) {
        Write-Host "✅ .NET 9 SDK is already installed" -ForegroundColor Green
        return $true
    }
    
    $dotnetInstallerUrl = "https://download.visualstudio.microsoft.com/download/pr/4e88f517-196e-4b17-a40c-2692c689661d/8e1c4e1a-4c0c-4c0c-8e1c-4e1a4c0c4c0c/dotnet-sdk-9.0.100-win-x64.exe"
    $dotnetInstallerPath = "$env:TEMP\dotnet-sdk-9.0.100-win-x64.exe"
    
    Write-Host "Installing .NET 9 SDK..." -ForegroundColor Cyan
    
    if (-not (Download-File -Url $dotnetInstallerUrl -OutputPath $dotnetInstallerPath)) {
        Write-Host "Failed to download .NET SDK. Please download it manually from: https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor Yellow
        Write-Host "After downloading, run the installer and then run this script again." -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "Running .NET SDK installer..." -ForegroundColor Cyan
    try {
        $process = Start-Process -FilePath $dotnetInstallerPath -ArgumentList "/quiet /norestart" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "Failed to install .NET SDK. Exit code: $($process.ExitCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Failed to run .NET SDK installer: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ .NET SDK installed successfully" -ForegroundColor Green
    return $true
}

# Function to install Windows SDK
function Install-WindowsSDK {
    $sdkInstallerUrl = "https://go.microsoft.com/fwlink/p/?linkid=2196241"
    $sdkInstallerPath = "$env:TEMP\winsdk.exe"
    
    Write-Host "Installing Windows SDK..." -ForegroundColor Cyan
    
    if (-not (Download-File -Url $sdkInstallerUrl -OutputPath $sdkInstallerPath)) {
        return $false
    }
    
    Write-Host "Running Windows SDK installer..." -ForegroundColor Cyan
    try {
        $process = Start-Process -FilePath $sdkInstallerPath -ArgumentList "/quiet /norestart" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "Failed to install Windows SDK. Exit code: $($process.ExitCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Failed to run Windows SDK installer: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ Windows SDK installed successfully" -ForegroundColor Green
    return $true
}

# Function to install Visual Studio Build Tools
function Install-VSBuildTools {
    $vsInstallerUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"
    $vsInstallerPath = "$env:TEMP\vs_buildtools.exe"
    
    Write-Host "Installing Visual Studio Build Tools..." -ForegroundColor Cyan
    
    if (-not (Download-File -Url $vsInstallerUrl -OutputPath $vsInstallerPath)) {
        return $false
    }
    
    Write-Host "Running Visual Studio Build Tools installer..." -ForegroundColor Cyan
    try {
        $process = Start-Process -FilePath $vsInstallerPath -ArgumentList "--add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools --add Microsoft.VisualStudio.Workload.MSBuildTools --quiet" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-Host "Failed to install Visual Studio Build Tools. Exit code: $($process.ExitCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Failed to run Visual Studio Build Tools installer: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ Visual Studio Build Tools installed successfully" -ForegroundColor Green
    return $true
}

# Main execution
Write-Host "=== Installing Prerequisites ===" -ForegroundColor Cyan
Write-Host "This script will install the necessary prerequisites for code signing." -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-Host "❌ This script must be run as Administrator." -ForegroundColor Red
    Write-Host "   Please right-click on PowerShell and select 'Run as Administrator'." -ForegroundColor Yellow
    exit 1
}

# Install prerequisites
$dotnetInstalled = Install-DotNetSDK
$sdkInstalled = Install-WindowsSDK
$vsInstalled = Install-VSBuildTools

# Summary
Write-Host "`n=== Installation Summary ===" -ForegroundColor Cyan
if ($dotnetInstalled -and $sdkInstalled -and $vsInstalled) {
    Write-Host "✅ All prerequisites installed successfully." -ForegroundColor Green
    Write-Host "   Please restart your computer to ensure all changes take effect." -ForegroundColor Yellow
} else {
    Write-Host "❌ Some prerequisites failed to install." -ForegroundColor Red
    Write-Host "   Please check the error messages above and try again." -ForegroundColor Yellow
    exit 1
} 