param(
    [Parameter(Mandatory = $true)]
    [string]$TargetDir
)

# Signs every .exe/.dll/.msi under $TargetDir with the self-signed Authenticode cert
# stored (base64) in the WINDOWS_PFX_BASE64 secret / WINDOWS_PFX_PASSWORD for its password.
# See USAGE.md for how the cert was generated and how to trust it on managed devices.

$ErrorActionPreference = "Stop"

# Timestamp servers occasionally time out/rate-limit in CI; retry a couple of them rather
# than failing the whole build on one flaky server.
$timestampServers = @(
    "http://timestamp.digicert.com",
    "http://timestamp.sectigo.com"
)
$maxAttemptsPerFile = 3

if (-not $env:WINDOWS_PFX_PASSWORD) {
    throw "WINDOWS_PFX_PASSWORD is not set - check the secret exists and is wired into this step's env."
}

if (-not (Test-Path $TargetDir)) {
    throw "TargetDir '$TargetDir' does not exist - nothing to sign."
}

$signtool = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $signtool) {
    throw "signtool.exe not found under Windows Kits - is the Windows SDK installed on this runner?"
}
Write-Host "Using signtool: $signtool"

$pfxPath = Join-Path $env:RUNNER_TEMP "ghostdesk-codesign.pfx"

try {
    [IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($env:WINDOWS_PFX_BASE64))

    $files = @(Get-ChildItem -Path (Join-Path $TargetDir "*") -Recurse -Include *.exe, *.dll, *.msi)

    if ($files.Count -eq 0) {
        throw "No .exe/.dll/.msi files found under '$TargetDir' - signing step would silently do nothing, treating that as an error."
    }

    Write-Host "Signing $($files.Count) file(s) under $TargetDir`:"
    foreach ($file in $files) {
        Write-Host "  - $($file.Name)"
    }

    foreach ($file in $files) {
        $signed = $false
        for ($attempt = 1; $attempt -le $maxAttemptsPerFile -and -not $signed; $attempt++) {
            $tsa = $timestampServers[($attempt - 1) % $timestampServers.Count]
            & $signtool sign /f $pfxPath /p $env:WINDOWS_PFX_PASSWORD /fd SHA256 /tr $tsa /td SHA256 $file.FullName
            if ($LASTEXITCODE -eq 0) {
                $signed = $true
                Write-Host "Signed $($file.Name) (attempt $attempt, $tsa)"
            }
            elseif ($attempt -lt $maxAttemptsPerFile) {
                Write-Warning "signtool failed on $($file.Name) via $tsa (attempt $attempt/$maxAttemptsPerFile), retrying..."
                Start-Sleep -Seconds 5
            }
        }
        if (-not $signed) {
            throw "signtool failed on $($file.FullName) after $maxAttemptsPerFile attempts."
        }
    }

    Write-Host "All $($files.Count) file(s) signed successfully."
}
finally {
    Remove-Item -Path $pfxPath -Force -ErrorAction SilentlyContinue
}
