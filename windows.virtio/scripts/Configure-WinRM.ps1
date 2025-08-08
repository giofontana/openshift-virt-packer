# --- This new block replaces 'winrm quickconfig -q' ---

Write-Host "Enabling WinRM Service..."
# Ensure the WinRM service is set to start automatically
Set-Service -Name "WinRM" -StartupType Automatic

# Create a new self-signed certificate for the listener
Write-Host "Creating self-signed certificate for WinRM HTTPS..."
$cert = New-SelfSignedCertificate -DnsName "packer-$(Get-Random)" -CertStoreLocation "cert:\LocalMachine\My"

# Extract just the hostname from the certificate's "CN=hostname" subject line.
$hostname = ($cert.Subject -split '=')[1]

# For debugging, show the extracted hostname and thumbprint
Write-Host "Certificate created with Subject: $($cert.Subject) and Thumbprint: $($cert.Thumbprint)"
Write-Host "Extracted Hostname for listener: $hostname"

# Create the WinRM HTTPS listener using the clean hostname
Write-Host "Creating WinRM HTTPS listener..."
New-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet @{Address='*';Transport='HTTPS'} -ValueSet @{HostName=$hostname; CertificateThumbprint=$cert.Thumbprint}

# Set basic WinRM service configurations using the modern WSMan provider
Write-Host "Configuring WinRM service options..."
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $true

# --- The rest of the script remains the same ---

# Set Network to Private to allow WinRM connections
Write-Host "Setting network profile to Private..."
$networkProfile = Get-NetConnectionProfile
Set-NetConnectionProfile -InterfaceIndex $networkProfile.InterfaceIndex -NetworkCategory Private

# Firewall rule for WinRM
Write-Host "Configuring firewall rule for WinRM..."
Remove-NetFirewallRule -Name "Packer WinRM" -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "Packer WinRM" -DisplayName "Packer WinRM" -Enabled True -Profile Private -Action Allow -Protocol TCP -LocalPort 5985,5986

# Enable RDP
Write-Host "Enabling Remote Desktop..."
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Disable complex passwords and password expiration
Write-Host "Disabling password complexity..."
secedit /export /cfg C:\secpol.cfg
(gc C:\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File C:\secpol.cfg
(gc C:\secpol.cfg).replace("MaximumPasswordAge = 42", "MaximumPasswordAge = -1") | Out-File C:\secpol.cfg
secedit /configure /db c:\windows\security\local.sdb /cfg C:\secpol.cfg /areas SECURITYPOLICY

# Add a 30-second pause to let the system stabilize before Packer connects
Write-Host "Configuration complete. Pausing for 30 seconds..."
Start-Sleep -Seconds 30