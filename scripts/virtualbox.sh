#!/bin/bash -eu

echo '==> Installing VirtualBox guest additions'
export KERN_DIR=/usr/src/kernels/`uname -r`
mount -o loop /root/VBoxGuestAdditions.iso /mnt
sh /mnt/VBoxLinuxAdditions.run --nox11 || true
umount /mnt
rm -f /root/VBoxGuestAdditions.iso

echo '==> Disabling VirtualBox X11 service'
chkconfig vboxadd-x11 off
