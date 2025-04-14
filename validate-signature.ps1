param(
    [Parameter(Mandatory=$false)]
    [string]$TargetFolder = ".\src\CodeSigningFunction\bin\Release\net9.0"
)

Write-Host "Validating code signatures in folder: $TargetFolder" -ForegroundColor Cyan

# Check if the target folder exists
if (-not (Test-Path -Path $TargetFolder)) {
    Write-Host "❌ Output folder not found: $TargetFolder" -ForegroundColor Red
    Write-Host "   Please build the project in Release mode first." -ForegroundColor Yellow
    exit 1
}

# Get all DLL and EXE files in the target folder
$files = Get-ChildItem -Path $TargetFolder -Recurse -Include *.dll, *.exe
if ($files.Count -eq 0) {
    Write-Host "❌ No assemblies found in $TargetFolder" -ForegroundColor Red
    Write-Host "   Please build the project in Release mode first." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found $($files.Count) assemblies to validate" -ForegroundColor Cyan
$hasErrors = $false

# Check each file
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

# Summary
if ($hasErrors) {
    Write-Host "`n❌ Some files failed validation. Please check the errors above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ All files are properly signed and valid." -ForegroundColor Green
    exit 0
} 