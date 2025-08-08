packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "rhel9" {
#  qemu_binary = "/usr/libexec/qemu-kvm" # you can set this variable if qemu binary is not on PATH.

  qemuargs = [
    ["-cpu", "host,migratable=on"]
  ]

  # Use a RHEL ISO locally
  iso_url = "file:///home/gfontana/Downloads/redhat/rhel-9.6-x86_64-dvd.iso"
  iso_checksum = "none"
  
  # SSH credentials defined in ks.cfg
  communicator     = "ssh"
  ssh_username     = "packer"
  ssh_password     = "packer"
  ssh_timeout      = "30m"

  shutdown_command = "echo 'packer' | sudo -S shutdown -P now"

  # Boot command
  boot_wait        = "10s"
  boot_command     = [
    "<up><tab>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg ",
    "<enter>"
  ]

  # General VM settings
  output_directory = "output"
  disk_size        = "10G"
  memory           = "4096"
  format           = "qcow2"
  accelerator      = "kvm"
  headless         = false # set to true in case the workstation has no GUI
  http_directory   = "http"
  
}

build {
  sources = ["source.qemu.rhel9"]

  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "echo 'RHEL image provisioned by Packer' | sudo tee /etc/motd"
    ]
  }

  # Final cleanup step to reduce image size
  provisioner "shell" {
    inline = ["sudo dnf clean all"]
  }

  # This block runs after the build is complete
  post-processor "shell-local" {
    inline = [
      "mv output/packer-* output/rhel9.qcow2"
    ]
  }  
}
