packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "windows-server-2019" {
  # --- ISO and Output Configuration ---
  iso_url            = "Windows2019.iso"
  iso_checksum       = "none"
  output_directory   = "output"
  vm_name            = "windows-server-2019-virtio.qcow2"

  # --- Virtual Machine Hardware ---
  accelerator        = "kvm"
  disk_size          = "40G"
  memory             = "4096"
  format             = "qcow2"
  headless           = false

  # --- ADD Driver CD Configuration ---
  # This creates a virtual CD with our automation files and drivers.
  cd_files = [
    "./autounattend.xml",
    "./scripts/Configure-WinRM.ps1",
    "./virtio/"
  ]
  cd_label = "PACKERDRV" # A label for our driver CD

  # --- Communicator Configuration ---
  communicator       = "winrm"
  winrm_username     = "Administrator"
  winrm_password     = "P@ssw0rd123!" # Must match the password in autounattend.xml
  winrm_timeout      = "6h"           # Windows updates can take a long time
  winrm_use_ssl      = false
  winrm_insecure     = true

  # --- Shutdown Behavior ---
  shutdown_command   = "shutdown /s /t 10 /f /c \"Packer Shutdown\""
}

build {
  sources = ["source.qemu.windows-server-2019"]


  provisioner "powershell" {

    elevated_user     = "Administrator"
    elevated_password = "P@ssw0rd123!"

    inline = [
      # Install virtio guest tools
      "Write-Host 'Installing vitio guest tools...'",
      "E:\\virtio\\virtio-win-guest-tools.exe /s /qn",
      "Write-Host 'QEMU Guest Agent installation complete.'",

      "Write-Host 'Installing Windows Updates... This may take a long time.'",   
      # 1. Install the NuGet package provider non-interactively
      "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force",
      # 2. Trust the default PowerShell Gallery to avoid prompts
      "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted",
      # 3. Now install the Windows Update module
      "Install-Module -Name PSWindowsUpdate -Force",
      # 4. Finally, run the updates
      "Get-WindowsUpdate -AcceptAll -Install -AutoReboot",
      "Write-Host 'Windows Update complete.'"
    ]
  }
}