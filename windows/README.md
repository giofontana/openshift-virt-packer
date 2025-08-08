# Building Windows images

## Option 1) ide and e1000e driver (simpler)

Set `windows2019.pkr.hcl` to use windows native drivers by uncomment lines below:

```
  disk_interface     = "ide"
  net_device         = "e1000"
```

## Option 2) virtio drivers

To use KVM virtio drivers (faster) you need to mount virtio drivers and set it to be used at `autounattend.xml`:

1. Download virtiowin ISO: https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md
2. Mount it in your workstation
3. Copy the entire viostor directory (the storage driver) into virtio folder.
4. Copy the entire NetKVM directory (the network driver) into virtio folder.
5. Set permissions:

```
sudo chown -R $(whoami) ./virtio
sudo chmod -R 755 ./virtio
```

6. Comment lines below of `windows2019.pkr.hcl`

```
  #disk_interface     = "ide"
  #net_device         = "e1000"
```

7. Uncomment lines below of `autounattend.xml`:

```
      <!-- <-- Remove this line
      <DriverPaths>
        <PathAndCredentials wcm:action="add" wcm:keyValue="1">
            <Path>E:\virtio\viostor\2k19\amd64</Path>
        </PathAndCredentials>
         <PathAndCredentials wcm:action="add" wcm:keyValue="2">
            <Path>E:\virtio\NetKVM\2k19\amd64</Path>
        </PathAndCredentials>
      </DriverPaths>      
      --> <-- Remove this line
```      