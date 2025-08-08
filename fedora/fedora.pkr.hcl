packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "fedora" {
#  qemu_binary = "/usr/libexec/qemu-kvm" # you can set this variable if qemu binary is not on PATH.
  # 1. Use a Fedora Server ISO
#  iso_url          = "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Server/x86_64/iso/Fedora-Server-netinst-x86_64-42-1.1.iso"
#  iso_checksum     = "sha256:231f3e0d1dc8f565c01a9f641b3d16c49cae44530074bc2047fe2373a721c82f"

  # --- ISO and Output Configuration ---
  iso_url            = "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Server/x86_64/iso/Fedora-Server-netinst-x86_64-42-1.1.iso"
  iso_checksum       = "sha256:231f3e0d1dc8f565c01a9f641b3d16c49cae44530074bc2047fe2373a721c82f"
  output_directory   = "output"
  vm_name            = "fedora.qcow2"

  # SSH credentials defined in ks.cfg
  communicator     = "ssh"
  ssh_username     = "packer"
  ssh_password     = "packer"
  ssh_timeout      = "30m"

  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  # Boot command
  boot_wait        = "10s"
  boot_command     = [
    "<up>e",
    "<down><down><end>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg ",
    "<f10>"
  ]

  # General VM settings
  disk_size        = "10G"
  memory           = "2048"
  format           = "qcow2"
  accelerator      = "kvm"
  headless         = false # set to true in case the workstation has no GUI
  http_directory   = "http"
}

build {
  sources = ["source.qemu.fedora"]

  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "echo 'Fedora image provisioned by Packer' | sudo tee /etc/motd"
    ]
  }

  # Final cleanup step to reduce image size
  provisioner "shell" {
    inline = ["sudo dnf clean all"]
  }

  # This block runs after the build is complete
#  post-processor "shell-local" {
#    inline = [
#      "mv output/packer-* output/fedora.qcow2"
#    ]
#  }  
}
