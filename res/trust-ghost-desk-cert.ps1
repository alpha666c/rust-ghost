# Run once (elevated) on each managed Windows device so it stops flagging Ghost Desk
# builds as untrusted. Ghost Desk is signed with our own self-signed Authenticode cert
# (not a public CA), so Windows needs to be told to trust it explicitly - this is that step.
#
# Usage (elevated PowerShell):
#   .\trust-ghost-desk-cert.ps1              # trust the cert (idempotent - safe to re-run)
#   .\trust-ghost-desk-cert.ps1 -Uninstall   # remove trust (e.g. after rotating the cert)
#
# Roll out at scale via GPO startup script or your RMM/MDM tool instead of running by hand.

#Requires -RunAsAdministrator

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$certPath = Join-Path $PSScriptRoot "ghost-desk-codesign.cer"

if (-not (Test-Path $certPath)) {
    throw "ghost-desk-codesign.cer not found next to this script."
}

$cert = Get-PfxCertificate -FilePath $certPath
Write-Host "Certificate: $($cert.Subject)"
Write-Host "Thumbprint:  $($cert.Thumbprint)"
Write-Host "Valid until: $($cert.NotAfter)"

if ($cert.NotAfter -lt (Get-Date)) {
    Write-Warning "This certificate has already expired - builds need to be re-signed with a new one."
}

$stores = @("Cert:\LocalMachine\Root", "Cert:\LocalMachine\TrustedPublisher")

if ($Uninstall) {
    foreach ($store in $stores) {
        $existing = Get-ChildItem $store -ErrorAction SilentlyContinue | Where-Object Thumbprint -eq $cert.Thumbprint
        if ($existing) {
            $existing | Remove-Item
            Write-Host "Removed from $store"
        }
        else {
            Write-Host "Not present in $store, nothing to remove"
        }
    }
    Write-Host "Ghost Desk code-signing certificate no longer trusted on this machine."
    return
}

foreach ($store in $stores) {
    $existing = Get-ChildItem $store -ErrorAction SilentlyContinue | Where-Object Thumbprint -eq $cert.Thumbprint
    if ($existing) {
        Write-Host "Already trusted in $store, skipping"
    }
    else {
        Import-Certificate -FilePath $certPath -CertStoreLocation $store | Out-Null
        Write-Host "Imported into $store"
    }
}

Write-Host "Ghost Desk code-signing certificate trusted on this machine."
