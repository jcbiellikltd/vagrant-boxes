#!/bin/bash -eu

echo '==> Cleaning up temporary network addresses'
rm -f /etc/udev/rules.d/70-persistent-net.rules
mkdir /etc/udev/rules.d/70-persistent-net.rules
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules
rm -rf /dev/.udev/

if [ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ]; then
	sed -i '/^HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-eth0
	sed -i '/^UUID/d' /etc/sysconfig/network-scripts/ifcfg-eth0
fi

echo '==> Cleaning up YUM cache'
yum -y -q clean all

echo '==> Removing temporary files'
rm -rf /tmp/*

echo '==> Removing unnecessary files'
rm -rf /usr/share/{man,doc,info,gnome/help}
rm -rf /usr/share/cracklib
rm -rf /usr/share/i18n
rm -rf /sbin/sln
rm -rf /etc/ssh/ssh_host_*
rm -rf /etc/ld.so.cache
ldconfig

echo '==> Cleaning out logs'
rm -rf /root/{VBoxGuestAdditions.iso,*.cfg,*.log*}
rm -rf /var/log/{dmesg,anaconda.*,*.old,vb*.log,VB*.log}

for file in $(find /var/log -type f); do
	> ${file}
done

echo '==> Removing Bash history'
unset HISTFILE
rm -f /root/.bash_history /home/vagrant/.bash_history

echo '==> Updating search index'
updatedb

echo '==> Clearing swap partiton'
readonly swapuuid=$(/sbin/blkid -o value -l -s UUID -t TYPE=swap)
readonly swappart=$(readlink -f /dev/disk/by-uuid/"$swapuuid")
/sbin/swapoff "$swappart"
dd if=/dev/zero of="$swappart" bs=1M &> /dev/null || true
/sbin/mkswap -U "$swapuuid" "$swappart" > /dev/null

echo '==> Zeroing empty space'
dd if=/dev/zero of=/EMPTY bs=1M &> /dev/null || true
rm -f /EMPTY

sync
