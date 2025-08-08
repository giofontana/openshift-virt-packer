# Build image

```
cd <image>
packer init .
packer build .
```

# Upload to OpenShift Virt as a bootable volume

```
virtctl image-upload dv rhel9-custom-dv \
  --image-path=./output/rhel9.qcow2 \
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

cat <<EOF | oc apply -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataSource
metadata:
  name: rhel9-custom-golden-image
  namespace: openshift-virtualization-os-images
  labels:
    instancetype.kubevirt.io/default-instancetype: u1.medium
    instancetype.kubevirt.io/default-preference: rhel9-custom  
spec:
  source:
    pvc:
      name: rhel9-custom-dv
      namespace: openshift-virtualization-os-images
EOF
```
