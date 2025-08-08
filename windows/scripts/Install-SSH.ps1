# Install the OpenSSH Server feature
Write-Host "Installing OpenSSH Server..."
dism /Online /Add-Capability /CapabilityName:OpenSSH.Server~~~~0.0.1.0

# Start the sshd service and set it to auto-start
Write-Host "Configuring sshd service..."
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# The default firewall rule is usually created automatically, but we ensure it exists.
Write-Host "Configuring firewall for SSH..."
if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" -Protocol TCP -LocalPort 22 -Action Allow
}