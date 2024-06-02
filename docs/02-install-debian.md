# Install Debian For Raspberry Pi

Based on the unofficial [Debian for Raspberry Pi](https://raspi.debian.net/) by Gunnar Wolf.

Download the latest supported image from: https://raspi.debian.net/tested-images/

NOTE: SD boot with root from SSD does not work with buster.

Decompress it:

``` bash
unxz 20210210_raspi_4_buster.img.xz
```

## TL;DR

There's a very basic script that perform all the steps required in this chapter,
moreover it does install `rpi-clone` repository into the `root` home of the SD card,
for later use.

``` bash
Usage: ./scripts/install-sd.sh -i <image> -d <device> -k <ssh-id.pub> -h <kluster-hostname>"
```

For example:

``` bash
./scripts/install-sd.sh -i distro-images/20210210_raspi_4_buster.img -d /dev/sdd -k ~/.ssh/kluster.pub -h "kluster-pi-01"
```

Or you can manually perform the follwoing procedure.

## Write Image

WARNING: THE FOLLOWING COMMAND IS REALLY DANGEROUS!

Insert the SD card in the USB card reader on host but don't mount it.

Write it to the SD card:

``` bash
sudo dd if=./20210210_raspi_4_buster.img.xz of=/dev/sdX
```

## Mount Partitions

``` bash
sudo mount /dev/sdX1 /mnt/boot
sudo mount /dev/sdX2 /mnt/root
```

## Configure System

Based on the [default configuration settings page](https://raspi.debian.net/defaults-and-settings/),
configure `root_authorized_key` and `hostname` by editing the `/mnt/boot/sysconf.txt` file as follows:

```
[...]

# root_authorized_key - Set an authorized key for a root ssh login
root_authorized_key=ecdsa-sha2-nistp521 AAAAEXXXXXXXXXXXXXX...XXXXXXX== user@hostname

# hostname - Set the system hostname.
hostname=kluster-01

[...]
``` 

Ensure SSH settings are the default for hardening security in the `/mnt/root/etc/ssh/sshd_config` file:

```
PermitRootLogin prohibit-password
PubkeyAuthentication yes
```

This should be enough to enable SSH access for `root` user and limit it to just ssh keys.

## Unmount Partitions 

``` bash
sudo umount /dev/sdX1
sudo umount /dev/sdX2
```

Now detach the first SD card and do the same for every other SD card.

