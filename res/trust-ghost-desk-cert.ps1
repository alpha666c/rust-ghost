# Run once (elevated) on each managed Windows device so it stops flagging Ghost Desk
# builds as untrusted. Ghost Desk is signed with our own self-signed Authenticode cert
# (not a public CA), so Windows needs to be told to trust it explicitly - this is that step.
#
# Usage (elevated PowerShell):
#   .\trust-ghost-desk-cert.ps1
#
# Roll out at scale via GPO startup script or your RMM/MDM tool instead of running by hand.

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$certPath = Join-Path $PSScriptRoot "ghost-desk-codesign.cer"

if (-not (Test-Path $certPath)) {
    throw "ghost-desk-codesign.cer not found next to this script."
}

Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null

Write-Host "Ghost Desk code-signing certificate trusted on this machine."
