# Clone SD image on SSD disk and mount it as root

NOTE: after a long research, and many trial and error attempts, I could not make the system to boot
entirely from SSD, but only mounting the `root` partition. Thus, at the moment, the following guide
allows you to boot from SD and mount `root` from SSD right after boot.
It could be possible to make it work by using the `vcgencmd` command to set the `BOOT_ORDER=0xf41`
parameter as explained in [the official Raspberry Pi guide](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#usb-mass-storage-boot).
At the time of writing this, Debian for raspberry does not have the `vcgencmd` in its repository,
and I had not yet time to workaround on this.

0. Hardware setup

We assume that all Raspberry Pis are up, and running the new Debian image from the SD.

1. Connect SSD to USB.

Each SSD should be attached to its RPi through the USB to SATA adapter.

NOTE: If you haven't used the `install-sd.sh` script, you'll have to manually
download `rpi-clone` repo, as follows. Otherwise, you can skip the next
3 steps and continue from the 5th step onwards.

NOTE: There's a script (`scripts/clone-root-to-ssd.sh`) which covers these steps as well, but my recommendation is to first
gain confidence with the following commands by running them manually a couple of times.

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

in this case `/dev/sda` is the target disk.

6. Prepare configuration files before the clone:

* replace `root=LABEL=RASPIROOT` with `root=LABEL=ROOT` in the `/boot/firmware/cmdline.txt` file;
* replace `LABEL=RASPIROOT` with `LABEL=ROOT` in the `/etc/fstab` file;
* replace `ROOTPART=LABEL=RASPIROOT` with `ROOTPART=LABEL=ROOT` in the `/etc/default/raspi-firmware` file.

Since we are touching the `cmdline.txt` file, we should as well set the `cgroups` required for running containers:

``` bash
console=tty0 console=ttyS1,115200 root=LABEL=ROOT rootfstype=ext4 fsck.repair=yes rootwait elevator=deadline cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset
```

Let's add the extra file to persist the changes:

``` bash
cat <<EOS > /etc/default/raspi-extra-cmdline
elevator=deadline cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset
EOS
```

7. Perform `apt update` before running `rpi-clone`.

``` bash
apt update
```

8. Preparing SSD

There are many ways we can use the SSD to expose the storage as persistent volume in Kubernetes. My recommendation at this stage
is to dedicate the first two partitions to `boot` and `root` respectively, and to use the remaining disk space as Kubernetes storage.

Before cloning the data with the `rpi-clone` script, the SSD should present the same partition table. To copy the partition table
we will use `sfdisk` to dump it as follows:

``` bash
sfdisk -d /dev/mmcblk1 > partition_table_sd
```

Then we write the table to the SSD:

``` bash
sfdisk /dev/sda < partition_table_sd
```

This allows `rpi-clone` script to automatically perform the right actions for cloning the SD data to the SDD (see point 7 of the
[README](https://github.com/billw2/rpi-clone?tab=readme-ov-file#7-clone-sd-card-to-usb-disk-with-extra-partitions)).

First, let's increase the size of the `root` partition on the SSD, using `cfdisk`, e.g. increase it to 32 or 64 GB:

``` bash
cfdisk /dev/sda
```

Then recreate the filsystem with the right label:

``` bash
mkfs.ext4 /dev/sda2 -L ROOT
```

9. Cloning SD to SSD

Run the `rpi-clone` script:

``` bash
./rpi-clone-master/rpi-clone /dev/sda
```

Output if some packages are missing:

``` bash
Command not found: rsync       Package required: rsync
Command not found: column      Package required: bsdmainutils

Do you want to apt-get install the packages?  (yes/no): yes
```

Answer `yes` and proceed.

Then:

``` bash
Booted disk: mmcblk1 15.9GB                Destination disk: sda 1.0TB
---------------------------------------------------------------------------
Part               Size    FS     Label           Part   Size    FS     Label
1 /boot/firmware   508.0M  fat16  --              1      508.0M  fat16  --
2 root              14.3G  ext4   RASPIROOT       2       64.0G  ext4   ROOT
---------------------------------------------------------------------------
== SYNC mmcblk1 file systems to sda ==
/boot/firmware        (82.0M used)   : SYNC to sda1 (508.0M size)
/                     (928.0M used)  : SYNC to sda2 (64.0G size)
---------------------------------------------------------------------------
Run setup script       : no.
Verbose mode           : no.
-----------------------:

Ok to proceed with the clone?  (yes/no): yes
```

Enter `yes` to proceed:

``` bash
Syncing file systems (can take a long time)
Syncing mounted partitions:
  Mounting /dev/sda2 on /mnt/clone
mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.
  => rsync // /mnt/clone with-root-excludes ...
  Mounting /dev/sda1 on /mnt/clone/boot/firmware
mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.
  => rsync /boot/firmware/ /mnt/clone/boot/firmware  ...

===============================
Done with clone to /dev/sda
   Start - 22:36:18    End - 22:36:29    Elapsed Time - 0:11

Cloned partitions are mounted on /mnt/clone for inspection or customizing.

Hit Enter when ready to unmount the /dev/sda partitions ...
  unmounting /mnt/clone/boot/firmware
  unmounting /mnt/clone
===============================
```

10. Reboot the RPi system to check whether the changes will be successfully applied:

``` bash
systemctl reboot
```

11. Reconnect and verify:

``` bash
lsblk
```

Output:

``` bash
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    0 931.5G  0 disk
|-sda1        8:1    0   508M  0 part
`-sda2        8:2    0    64G  0 part /
mmcblk1     179:0    0  14.8G  0 disk
|-mmcblk1p1 179:1    0   508M  0 part /boot/firmware
`-mmcblk1p2 179:2    0  14.3G  0 part
```
