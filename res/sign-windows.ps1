param(
    [Parameter(Mandatory = $true)]
    [string]$TargetDir
)

# Signs every .exe/.dll/.msi under $TargetDir with the self-signed Authenticode cert
# stored (base64) in the WINDOWS_PFX_BASE64 secret / WINDOWS_PFX_PASSWORD for its password.
# See USAGE.md for how the cert was generated and how to trust it on managed devices.

$ErrorActionPreference = "Stop"

$signtool = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $signtool) {
    throw "signtool.exe not found under Windows Kits - is the Windows SDK installed on this runner?"
}

$pfxPath = Join-Path $env:RUNNER_TEMP "ghostdesk-codesign.pfx"
[IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($env:WINDOWS_PFX_BASE64))

try {
    $files = Get-ChildItem -Path (Join-Path $TargetDir "*") -Recurse -Include *.exe, *.dll, *.msi
    foreach ($file in $files) {
        & $signtool sign /f $pfxPath /p $env:WINDOWS_PFX_PASSWORD /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 $file.FullName
        if ($LASTEXITCODE -ne 0) {
            throw "signtool failed on $($file.FullName)"
        }
    }
}
finally {
    Remove-Item -Path $pfxPath -Force -ErrorAction SilentlyContinue
}
