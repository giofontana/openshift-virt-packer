# Packer for OpenShift Virtualization
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
3. Copy the entire viostor directory (the storage driver) into `windows.virtio/virtio/viostor` folder.
4. Copy the entire NetKVM directory (the network driver) into `windows.virtio/virtio/NetKVM` folder.
6. Copy the virtio guest tools installer (`virtio-win-guest-tools.exe`) into `windows.virtio/virtio/` folder.
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
virtctl image-upload dv win2k19-custom \
  --image-path=./output/windows-server-2019-virtio.qcow2 \
  --size=100Gi \
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
    openshift.io/display-name: Microsoft Windows Server 2019
    openshift.io/documentation-url: 'https://access.redhat.com'
    tags: 'hidden,kubevirt,windows'
    openshift.io/support-url: 'https://access.redhat.com'
    iconClass: icon-windows
    openshift.io/provider-display-name: Red Hat
  labels:
    instancetype.kubevirt.io/arch: amd64
    instancetype.kubevirt.io/common-instancetypes-version: 1.2.1-34-g416eceef
    instancetype.kubevirt.io/os-type: windows
    instancetype.kubevirt.io/vendor: redhat.com
  name: win2k19-custom
spec:
  annotations:
    vm.kubevirt.io/os: windows
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
  name: win2k19-custom-golden-image
  namespace: openshift-virtualization-os-images
  labels:
    instancetype.kubevirt.io/default-instancetype: u1.medium
    instancetype.kubevirt.io/default-preference: win2k19-custom # Set to VirtualMachineClusterPreference created in the last step or use an existing one
spec:
  source:
    pvc:
      name: win2k19-custom
      namespace: openshift-virtualization-os-images
EOF
```

# (Optional) Create new Template

Example:
```
cat <<'EOF' | oc apply -f -
kind: Template
apiVersion: template.openshift.io/v1
metadata:
  name: windows2k19-server-medium-custom
  namespace: openshift
  labels:
    os.template.kubevirt.io/win2k19: "true"
    workload.template.kubevirt.io/server: "true"
    flavor.template.kubevirt.io/medium: "true"
    template.kubevirt.io/type: vm
    template.kubevirt.io/version: "v1.0"
    template.kubevirt.io/architecture: "amd64"
  annotations:

    openshift.io/display-name: "Microsoft Windows Server 2019 Custom VM"
    description: >-
      Custom template for Microsoft Windows Server 2019 VM.
      A PVC with the Windows disk image must be available.
    tags: "hidden,kubevirt,virtualmachine,windows"
    iconClass: "icon-windows"
    openshift.io/provider-display-name: ""
    openshift.io/documentation-url: "https://github.com/kubevirt/common-templates"
    openshift.io/support-url: "https://github.com/kubevirt/common-templates/issues"
    template.openshift.io/bindable: "false"
    template.kubevirt.io/version: v1alpha1
    defaults.template.kubevirt.io/disk: rootdisk
    defaults.template.kubevirt.io/network: default
    template.kubevirt.io/editable: |
      /objects[0].spec.template.spec.domain.cpu.cores
      /objects[0].spec.template.spec.domain.memory.guest
      /objects[0].spec.template.spec.domain.devices.disks
      /objects[0].spec.template.spec.volumes
      /objects[0].spec.template.spec.networks
    name.os.template.kubevirt.io/win2k19: Microsoft Windows Server Custom 2019
objects:
  - apiVersion: kubevirt.io/v1
    kind: VirtualMachine
    metadata:
      annotations:
        vm.kubevirt.io/validations: |
          [
            {
              "name": "minimal-required-memory",
              "path": "jsonpath::.spec.domain.memory.guest",
              "rule": "integer",
              "message": "This VM requires more memory.",
              "min": 536870912
            }, {
              "name": "windows-virtio-bus",
              "path": "jsonpath::.spec.domain.devices.disks[*].disk.bus",
              "valid": "jsonpath::.spec.domain.devices.disks[*].disk.bus",
              "rule": "enum",
              "message": "virtio disk bus type has better performance, install virtio drivers in VM and change bus type",
              "values": ["virtio"],
              "justWarning": true
            }, {
              "name": "windows-disk-bus",
              "path": "jsonpath::.spec.domain.devices.disks[*].disk.bus",
              "valid": "jsonpath::.spec.domain.devices.disks[*].disk.bus",
              "rule": "enum",
              "message": "disk bus has to be either virtio or sata or scsi",
              "values": ["virtio", "sata", "scsi"]
            }, {
              "name": "windows-cd-bus",
              "path": "jsonpath::.spec.domain.devices.disks[*].cdrom.bus",
              "valid": "jsonpath::.spec.domain.devices.disks[*].cdrom.bus",
              "rule": "enum",
              "message": "cd bus has to be sata",
              "values": ["sata"]
            }
          ]
      labels:
        app: '${NAME}'
        vm.kubevirt.io/template: windows2k19-server-medium-custom
        vm.kubevirt.io/template.revision: '1'
        vm.kubevirt.io/template.namespace: openshift
      name: '${NAME}'
    spec:
      dataVolumeTemplates:
        - apiVersion: cdi.kubevirt.io/v1beta1
          kind: DataVolume
          metadata:
            name: '${NAME}'
          spec:
            sourceRef:
              kind: DataSource
              name: '${DATA_SOURCE_NAME}'
              namespace: '${DATA_SOURCE_NAMESPACE}'
            storage:
              resources:
                requests:
                  storage: 120Gi
      runStrategy: Halted
      template:
        metadata:
          annotations:
            vm.kubevirt.io/flavor: medium
            vm.kubevirt.io/os: windows2k19
            vm.kubevirt.io/workload: server
          labels:
            kubevirt.io/domain: '${NAME}'
            kubevirt.io/size: medium
        spec:
          architecture: amd64
          domain:
            clock:
              timer:
                hpet:
                  present: false
                hyperv: {}
                pit:
                  tickPolicy: delay
                rtc:
                  tickPolicy: catchup
              utc: {}
            cpu:
              cores: 1
              sockets: 1
              threads: 1
            devices:
              disks:
                - disk:
                    bus: virtio
                  name: rootdisk
              inputs:
                - bus: usb
                  name: tablet
                  type: tablet
              interfaces:
                - masquerade: {}
                  model: virtio
                  name: default
            features:
              acpi: {}
              apic: {}
              hyperv:
                reenlightenment: {}
                ipi: {}
                synic: {}
                synictimer:
                  direct: {}
                spinlocks:
                  spinlocks: 8191
                reset: {}
                relaxed: {}
                vpindex: {}
                runtime: {}
                tlbflush: {}
                frequencies: {}
                vapic: {}
              smm: {}
            memory:
              guest: 4Gi
          networks:
            - name: default
              pod: {}
          terminationGracePeriodSeconds: 3600
          volumes:
            - dataVolume:
                name: '${NAME}'
              name: rootdisk
parameters:
  - name: NAME
    description: VM name
    generate: expression
    from: 'win2019-custom-[a-z0-9]{6}'
  - name: DATA_SOURCE_NAME
    description: Name of the DataSource to clone
    value: win2k19-custom-golden-image
  - name: DATA_SOURCE_NAMESPACE
    description: Namespace of the DataSource
    value: openshift-virtualization-os-images
EOF
```

5. Deploy VM creation from Template (from command line):

```
oc process windows2k19-server-medium-custom -n openshift \
  -p NAME=vm-win-test \
  -p DATA_SOURCE_NAME=win2k19-custom-golden-image \
  -p DATA_SOURCE_NAMESPACE=openshift-virtualization-os-images \
  -p ROOT_DISK_SIZE=110Gi | oc -n packer apply -f -
```

# (Optional) Red Hat Advanced Cluster Management

Red Hat ACM governance module can be used to distribute the template into multiple clusters.

Example of ACM Policy:

```yaml
apiVersion: policy.open-cluster-management.io/v1
kind: Policy
metadata:
  name: pol-kv-win2k19-tpl
  namespace: open-cluster-management-policies
  annotations:
    policy.open-cluster-management.io/standards: Custom
    policy.open-cluster-management.io/categories: Custom Configuration
    policy.open-cluster-management.io/controls: CM-2 Baseline Configuration
spec:
  remediationAction: enforce
  disabled: false
  policy-templates:
    - objectDefinition:
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: cfg-kv-win2k19-tpl
        spec:
          remediationAction: enforce
          severity: medium
          object-templates:
            - complianceType: musthave
              objectDefinition:
                kind: Template
                apiVersion: template.openshift.io/v1
                metadata:
                  name: windows2k19-server-medium-custom
                  namespace: openshift
                  labels:
                    os.template.kubevirt.io/win2k19: "true"
                    workload.template.kubevirt.io/server: "true"
                    flavor.template.kubevirt.io/medium: "true"
                    template.kubevirt.io/type: vm
                    template.kubevirt.io/version: "v1.0"
                    template.kubevirt.io/architecture: "amd64"
                  annotations:
                    openshift.io/display-name: "Microsoft Windows Server 2019 Custom VM"
                    description: >-
                      Custom template for Microsoft Windows Server 2019 VM.
                      A PVC with the Windows disk image must be available.
                    tags: "hidden,kubevirt,virtualmachine,windows"
                    iconClass: "icon-windows"
                    openshift.io/provider-display-name: ""
                    openshift.io/documentation-url: "https://github.com/kubevirt/common-templates"
                    openshift.io/support-url: "https://github.com/kubevirt/common-templates/issues"
                    template.openshift.io/bindable: "false"
                    template.kubevirt.io/version: v1alpha1
                    defaults.template.kubevirt.io/disk: rootdisk
                    defaults.template.kubevirt.io/network: default
                    template.kubevirt.io/editable: |
                      /objects[0].spec.template.spec.domain.cpu.cores
                      /objects[0].spec.template.spec.domain.memory.guest
                      /objects[0].spec.template.spec.domain.devices.disks
                      /objects[0].spec.template.spec.volumes
                      /objects[0].spec.template.spec.networks
                    name.os.template.kubevirt.io/win2k19: Microsoft Windows Server Custom 2019
                objects:
                  - apiVersion: kubevirt.io/v1
                    kind: VirtualMachine
                    metadata:
                      annotations:
                        vm.kubevirt.io/validations: |
                          [
                            {
                              "name": "minimal-required-memory",
                              "path": "jsonpath::.spec.domain.memory.guest",
                              "rule": "integer",
                              "message": "This VM requires more memory.",
                              "min": 536870912
                            }, {
                              "name": "windows-virtio-bus",
                              "path": "jsonpath::.spec.domain.devices.disks[*].disk.bus",
                              "valid": "jsonpath::.spec.domain.devices.disks[*].disk.bus",
                              "rule": "enum",
                              "message": "virtio disk bus type has better performance, install virtio drivers in VM and change bus type",
                              "values": ["virtio"],
                              "justWarning": true
                            }, {
                              "name": "windows-disk-bus",
                              "path": "jsonpath::.spec.domain.devices.disks[*].disk.bus",
                              "valid": "jsonpath::.spec.domain.devices.disks[*].disk.bus",
                              "rule": "enum",
                              "message": "disk bus has to be either virtio or sata or scsi",
                              "values": ["virtio", "sata", "scsi"]
                            }, {
                              "name": "windows-cd-bus",
                              "path": "jsonpath::.spec.domain.devices.disks[*].cdrom.bus",
                              "valid": "jsonpath::.spec.domain.devices.disks[*].cdrom.bus",
                              "rule": "enum",
                              "message": "cd bus has to be sata",
                              "values": ["sata"]
                            }
                          ]
                      labels:
                        app: '${NAME}'
                        vm.kubevirt.io/template: windows2k19-server-medium-custom
                        vm.kubevirt.io/template.revision: '1'
                        vm.kubevirt.io/template.namespace: openshift
                      name: '${NAME}'
                    spec:
                      dataVolumeTemplates:
                        - apiVersion: cdi.kubevirt.io/v1beta1
                          kind: DataVolume
                          metadata:
                            name: '${NAME}'
                          spec:
                            sourceRef:
                              kind: DataSource
                              name: '${DATA_SOURCE_NAME}'
                              namespace: '${DATA_SOURCE_NAMESPACE}'
                            storage:
                              resources:
                                requests:
                                  storage: '${ROOT_DISK_SIZE}'
                      runStrategy: Halted
                      template:
                        metadata:
                          annotations:
                            vm.kubevirt.io/flavor: medium
                            vm.kubevirt.io/os: windows2k19
                            vm.kubevirt.io/workload: server
                          labels:
                            kubevirt.io/domain: '${NAME}'
                            kubevirt.io/size: medium
                        spec:
                          architecture: amd64
                          domain:
                            clock:
                              timer:
                                hpet:
                                  present: false
                                hyperv: {}
                                pit:
                                  tickPolicy: delay
                                rtc:
                                  tickPolicy: catchup
                              utc: {}
                            cpu:
                              cores: 1
                              sockets: 1
                              threads: 1
                            devices:
                              disks:
                                - disk:
                                    bus: virtio
                                  name: rootdisk
                              inputs:
                                - bus: usb
                                  name: tablet
                                  type: tablet
                              interfaces:
                                - masquerade: {}
                                  model: virtio
                                  name: default
                            features:
                              acpi: {}
                              apic: {}
                              hyperv:
                                reenlightenment: {}
                                ipi: {}
                                synic: {}
                                synictimer:
                                  direct: {}
                                spinlocks:
                                  spinlocks: 8191
                                reset: {}
                                relaxed: {}
                                vpindex: {}
                                runtime: {}
                                tlbflush: {}
                                frequencies: {}
                                vapic: {}
                              smm: {}
                            firmware:
                              bootloader:
                                preferredUseBios: true
                            memory:
                              guest: 4Gi
                          networks:
                            - name: default
                              pod: {}
                          terminationGracePeriodSeconds: 3600
                          volumes:
                            - dataVolume:
                                name: '${NAME}'
                              name: rootdisk
                parameters:
                  - name: NAME
                    description: VM name
                    generate: expression
                    from: 'win2019-custom-[a-z0-9]{6}'
                  - name: DATA_SOURCE_NAME
                    description: Name of the DataSource to clone
                    value: win2k19
                  - name: DATA_SOURCE_NAMESPACE
                    description: Namespace of the DataSource
                    value: openshift-virtualization-os-images
                  - name: ROOT_DISK_SIZE
                    description: Size of the root disk
                    value: 120Gi
---
apiVersion: cluster.open-cluster-management.io/v1beta1
kind: Placement
metadata:
  name: pl-kv-win2k19-tpl
  namespace: open-cluster-management-policies
spec:
  predicates:
    - requiredClusterSelector:
        labelSelector:
          matchExpressions:
            - key: kubevirt
              operator: Exists
---
apiVersion: policy.open-cluster-management.io/v1
kind: PlacementBinding
metadata:
  name: pb-kv-win2k19-tpl
  namespace: open-cluster-management-policies
placementRef:
  name: pl-kv-win2k19-tpl
  kind: Placement
  apiGroup: cluster.open-cluster-management.io
subjects:
  - name: pol-kv-win2k19-tpl
    kind: Policy
    apiGroup: policy.open-cluster-management.io
```