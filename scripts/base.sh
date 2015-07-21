#!/bin/bash -eu

echo '==> Disabling boot splash'
sed -i "s/rhgb //" /boot/grub/grub.conf

echo '==> Importing RPM keys'
rpm --import /etc/pki/rpm-gpg/*

echo '==> Disabling SELinux'
sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config

echo '==> Configuring services'
chkconfig netfs off
chkconfig kdump off
chkconfig iptables off
chkconfig ip6tables off
chkconfig crond off
chkconfig ntpd on
