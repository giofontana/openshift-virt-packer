# Build image

```
cd <image>
packer init .
packer build .
```

# Upload to OpenShift Virt as a bootable volume

```
virtctl image-upload dv fedora-custom-dv \
  --image-path=./output/fedora.qcow2 \
  --size=30Gi \
  --access-mode=ReadWriteOnce \
  --storage-class=ocs-storagecluster-ceph-rbd-virtualization \
  --insecure \
  -n openshift-virtualization-os-images

cat <<EOF | oc apply -f -
apiVersion: instancetype.kubevirt.io/v1beta1
kind: VirtualMachineClusterPreference
metadata:
  annotations:
    kubevirt.io/install-strategy-registry: ''
    openshift.io/display-name: Fedora (amd64)
    openshift.io/documentation-url: 'https://access.redhat.com'
    tags: 'hidden,kubevirt,fedora'
    openshift.io/support-url: 'https://access.redhat.com'
    iconClass: icon-fedora
    openshift.io/provider-display-name: Red Hat
  labels:
    instancetype.kubevirt.io/arch: amd64
    instancetype.kubevirt.io/common-instancetypes-version: 1.2.1-34-g416eceef
    instancetype.kubevirt.io/os-type: linux
    instancetype.kubevirt.io/vendor: redhat.com
  name: fedora-custom
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

cat <<EOF | oc apply -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataSource
metadata:
  name: fedora-custom-golden-image
  namespace: openshift-virtualization-os-images
  labels:
    instancetype.kubevirt.io/default-instancetype: u1.medium
    instancetype.kubevirt.io/default-preference: fedora-custom  
spec:
  source:
    pvc:
      name: fedora-custom-dv
      namespace: openshift-virtualization-os-images
EOF
```
