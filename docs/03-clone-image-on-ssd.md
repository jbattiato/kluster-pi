# Clone SD image on SSD disk and mount it as root

0. Hardware setup

We assume that all Raspberry Pis are up, and running the new Debian image from the SD.

1. Connect SSD to USB.

Each SSD should be attached to its RPi through the USB to SATA adapter.

NOTE: If you haven't used the `install-sd.sh` script, you'll have to manually
download `rpi-clone` repo, as follows. Otherwise, you can skip the next
3 steps and continue from the 5th step onwards.

2. On host download `rpi-clone` compressed directory [from official GitHub repo](https://github.com/billw2/rpi-clone).

3. Unzip it:

``` bash
unzip master.zip
```

4. and SCP it into the `root` home on RPis:

``` bash
scp -r rpi-clone-master root@<RPi-address>
```

5. Now connect to the Raspberry Pis and execute the base checks:

``` bash
lsblk
```

Ouptut:

``` bash
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda           8:0    0 931.5G  0 disk
mmcblk1     179:0    0  14.8G  0 disk 
|-mmcblk1p1 179:1    0   299M  0 part /boot/firmware
`-mmcblk1p2 179:2    0  14.5G  0 part /
```

6. Prepare configuration files to be copied:

Change `root=LABEL=RASPIROOT` to `root=LABEL=ROOT` in the follwoing files:

* `/boot/firmware/cmdline.txt`
* `/etc/fstab`

Since we are touching the `cmdline.txt` file, we should as well set the `cgroups` required for running containers:

``` bash
console=serial0,115200 console=tty1 root=LABEL=ROOT rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset
```

7. Perform `apt update` before running `rpi-clone`.

``` bash
apt update
```

8. Run the `rpi-clone` script:

``` bash
./rpi-clone-master/rpi-clone /dev/sda
```

Output (if `rsync` is not installed):

``` bash
Command not found: rsync       Package required: rsync

Do you want to apt-get install the packages?  (yes/no):
```

Then:

``` bash
Booted disk: mmcblk1 15.9GB                Destination disk: sda 1.0TB
---------------------------------------------------------------------------
Part               Size    FS     Label           Part   Size  FS  Label  
1 /boot/firmware   299.0M  fat16  --                                      
2 root              14.5G  ext4   RASPIROOT                               
---------------------------------------------------------------------------
== Initialize: IMAGE partition table - partition number mismatch: 2 -> 0 ==
1 /boot/firmware      (72.5M used)   : MKFS  SYNC to sda1
2 root                (782.0M used)  : RESIZE  MKFS  SYNC to sda2
---------------------------------------------------------------------------
Run setup script       : no.
Verbose mode           : no.
-----------------------:
** WARNING **          : All destination disk sda data will be overwritten!
-----------------------:

Initialize and clone to the destination disk sda?  (yes/no): yes
```

Insert `ROOT` when asked for file system label:

``` bash
Optional destination ext type file system label (16 chars max): ROOT

Initializing
  Imaging past partition 1 start.
  => dd if=/dev/mmcblk1 of=/dev/sda bs=1M count=5 ...
  Resizing destination disk last partition ...
    Resize success.
  Changing destination Disk ID ...
  => mkfs -t vfat  /dev/sda1 ...
  => mkfs -t ext4  /dev/sda2 ...

Syncing file systems (can take a long time)
Syncing mounted partitions:
  Mounting /dev/sda2 on /mnt/clone
  => rsync // /mnt/clone with-root-excludes ...
  Mounting /dev/sda1 on /mnt/clone/boot/firmware
  => rsync /boot/firmware/ /mnt/clone/boot/firmware  ...

===============================
Done with clone to /dev/sda
   Start - 21:07:04    End - 21:07:48    Elapsed Time - 0:44

Cloned partitions are mounted on /mnt/clone for inspection or customizing. 

Hit Enter when ready to unmount the /dev/sda partitions ...
  unmounting /mnt/clone/boot/firmware
  unmounting /mnt/clone
===============================
```

9. Reboot the RPi system to check whether the changes will be successfully applied:

``` bash
systemctl reboot
```

10. Reconnect and verify:

``` bash
lsblk
```

Output:

``` bash
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda           8:0    0 931.5G  0 disk
|-sda1        8:1    0   299M  0 part
`-sda2        8:2    0 931.2G  0 part /
mmcblk1     179:0    0  14.9G  0 disk
|-mmcblk1p1 179:1    0   299M  0 part /boot/firmware
`-mmcblk1p2 179:2    0  14.6G  0 part
```

WARNING: since we changed the label to `ROOT`, everytime we upgrade Debian, that label
will be changed back to `RASPIROOT` in the `cmdline.txt` file, preventing the node to
properly reboot using the correct partition. In case the node won't come up after an upgrade,
turn it off, mount the SD card on another computer and change it back to `root=LABEL=ROOT`.

