# openshift-virt-packer
Examples of Packer with OpenShift Virtualization

# Packer installation

_Tested on RHEL 9 and Fedora_

```
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install packer
```

# Install qemu-kvm

```
sudo dnf install qemu-kvm
```

# Build image with packer and upload it to OpenShift Virtualization

Follow instructions at:
fedora/README.md
rhel9/README.md
windows/README.md

# Building Windows images

Pre-req: Install virtio-win drivers:
1. Download virtiowin ISO: https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md
2. Mount it
3. Copy the entire viostor directory (the storage driver) into windows/virtio folder.
4. Copy the entire NetKVM directory (the network driver) into windows/virtio folder.
5. Set permissions:

```
sudo chown -R $(whoami) ./virtio
sudo chmod -R 755 ./virtio
```
