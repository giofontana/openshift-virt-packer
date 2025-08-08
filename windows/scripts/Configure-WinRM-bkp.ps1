# Loosen security for WinRM
winrm quickconfig -q
winrm set winrm/config/service/Auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'

# Set Network to Private to allow WinRM connections
$networkProfile = Get-NetConnectionProfile
Set-NetConnectionProfile -InterfaceIndex $networkProfile.InterfaceIndex -NetworkCategory Private

# Firewall rule for WinRM
New-NetFirewallRule -Name "Packer WinRM" -DisplayName "Packer WinRM" -Enabled True -Profile Private -Action Allow -Protocol TCP -LocalPort "5985,5986"

# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Disable complex passwords and password expiration
secedit /export /cfg C:\secpol.cfg
(gc C:\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File C:\secpol.cfg
(gc C:\secpol.cfg).replace("MaximumPasswordAge = 42", "MaximumPasswordAge = -1") | Out-File C:\secpol.cfg
secedit /configure /db c:\windows\security\local.sdb /cfg C:\secpol.cfg /areas SECURITYPOLICY