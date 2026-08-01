param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths
)

$ErrorActionPreference = "Stop"
$CertificatePath = $env:WINDOWS_SIGNING_CERTIFICATE_PATH
$CertificatePassword = $env:WINDOWS_SIGNING_CERTIFICATE_PASSWORD
$TimestampUrl = if ($env:WINDOWS_TIMESTAMP_URL) {
    $env:WINDOWS_TIMESTAMP_URL
} else {
    "http://timestamp.sectigo.com"
}

if (-not $CertificatePath -or -not $CertificatePassword) {
    throw "Windows Authenticode certificate path and password are required."
}
if (-not (Test-Path -LiteralPath $CertificatePath)) {
    throw "Windows Authenticode certificate file was not found."
}

$SignTool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" `
    -Filter signtool.exe -Recurse -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if (-not $SignTool) {
    throw "signtool.exe was not found."
}

foreach ($Path in $Paths) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Signing target was not found: $Path"
    }
    & $SignTool.FullName sign /fd SHA256 /td SHA256 /tr $TimestampUrl `
        /f $CertificatePath /p $CertificatePassword $Path
    if ($LASTEXITCODE -ne 0) { throw "Authenticode signing failed." }
    & $SignTool.FullName verify /pa /all $Path
    if ($LASTEXITCODE -ne 0) { throw "Authenticode verification failed." }
}
