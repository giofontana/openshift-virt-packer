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

# Build image with Packer

## Linux

Build the image:

```
cd <image> # (fedora/rhel9/windows/...)
packer init .
packer build .
```

Notes: 
* You can use `PACKER_LOG=1 packer build .` for a more verbose output.
* For RHEL it expects the ISO DVD (`rhel-9.6-x86_64-dvd.iso`) to be in the `rhel9` folder. It is not necessary for Fedora (it downloads the ISO from `download.fedoraproject.org`)

## Windows

There are two options to build images for Windows. Both of them are available in this repository.

### Option 1) Using ide and e1000e driver (simpler, but slower on KVM)

This option will use windows native drivers. Although native, the overall VM performance will be slower on KVM than option 2.

Build the image
```
cd windows
packer init .
packer build .
```

Notes: 
* You can use `PACKER_LOG=1 packer build .` for a more verbose output.
* It expects the ISO DVD (`Windows2019.iso`) to be in the `windows` folder.

### Option 2) virtio drivers (prefered method for KVM)

Prefered for KVM. To use KVM virtio drivers (faster) you need to mount virtio drivers inside the VM and set it to be used at `autounattend.xml`:

1. Download virtiowin ISO: https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md
2. Mount it in your workstation
3. Copy the entire viostor directory (the storage driver) into windows.virtio/virtio/viostor folder.
4. Copy the entire NetKVM directory (the network driver) into windows.virtio/virtio/NetKVM folder.
5. Set permissions:

```
sudo chown -R $(whoami) windows.virtio/virtio
sudo chmod -R 755 windows.virtio/virtio
```

Build the image
```
cd windows.virtio
packer init .
packer build .
```

Notes: 
* You can use `PACKER_LOG=1 packer build .` for a more verbose output.
* It expects the ISO DVD (`Windows2019.iso`) to be in the `windows.virtio` folder.

# Upload image to OpenShift Virt as a bootable volume

1. Upload image to OpenShift Virt as a DataVolume:
```
virtctl image-upload dv <image>-dv \
  --image-path=./output/<image>.qcow2 \
  --size=30Gi \
  --access-mode=ReadWriteOnce \
  --storage-class=ocs-storagecluster-ceph-rbd-virtualization \
  --insecure \
  -n openshift-virtualization-os-images
```

Example:
```
virtctl image-upload dv rhel9-custom-dv \
  --image-path=./output/rhel9.qcow2 \
  --size=30Gi \
  --access-mode=ReadWriteOnce \
  --storage-class=ocs-storagecluster-ceph-rbd-virtualization \
  --insecure \
  -n openshift-virtualization-os-images
```

2. (Optional) Create a new VirtualMachineClusterPreference.

Example:

```
cat <<EOF | oc apply -f -
apiVersion: instancetype.kubevirt.io/v1beta1
kind: VirtualMachineClusterPreference
metadata:
  annotations:
    kubevirt.io/install-strategy-registry: ''
    openshift.io/display-name: Red Hat Enterprise Linux 9 (amd64)
    openshift.io/documentation-url: 'https://access.redhat.com'
    tags: 'hidden,kubevirt,rhel'
    openshift.io/support-url: 'https://access.redhat.com'
    iconClass: icon-rhel
    openshift.io/provider-display-name: Red Hat
  labels:
    instancetype.kubevirt.io/arch: amd64
    instancetype.kubevirt.io/common-instancetypes-version: 1.2.1-34-g416eceef
    instancetype.kubevirt.io/os-type: linux
    instancetype.kubevirt.io/vendor: redhat.com
  name: rhel9-custom
spec:
  annotations:
    vm.kubevirt.io/os: linux
  devices:
    preferredDiskBus: virtio
    preferredInterfaceModel: virtio
    preferredRng: {}
  features:
    preferredSmm: {}
  firmware:
    preferredUseBios: true
  requirements:
    cpu:
      guest: 1
    memory:
      guest: 2Gi
EOF
```

3. Create new Bootable Volume (`DataSource`)

Example:
```
cat <<EOF | oc apply -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataSource
metadata:
  name: rhel9-custom-golden-image
  namespace: openshift-virtualization-os-images
  labels:
    instancetype.kubevirt.io/default-instancetype: u1.medium
    instancetype.kubevirt.io/default-preference: rhel9-custom # Set to VirtualMachineClusterPreference created in the last step or use an existing one
spec:
  source:
    pvc:
      name: rhel9-custom-dv
      namespace: openshift-virtualization-os-images
EOF
```
