#!/bin/bash -eu

echo '==> Storing box build time'
date > /etc/vagrant_box_build_time

echo '==> Adding vagrant user'
/usr/sbin/groupadd vagrant
/usr/sbin/useradd vagrant -g vagrant -G wheel
echo 'vagrant:vagrant' | chpasswd
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
echo 'Defaults !requiretty' >> /etc/sudoers.d/vagrant
echo 'vagrant ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers.d/vagrant
echo 'Defaults:vagrant env_keep += SSH_AUTH_SOCK' >> /etc/sudoers.d/vagrant
chmod 0440 /etc/sudoers.d/vagrant

echo '==> Downloading vagrant insecure pubic key'
mkdir -pm 700 /home/vagrant/.ssh
curl -sSkL https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub -o /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant /home/vagrant/.ssh

echo '==> Applying Bash tweaks'
echo 'Welcome to your Vagrant-built virtual machine.' > /etc/motd
echo '[ -n "$SSH_CONNECTION" ] && cd /vagrant # cd-to-directory' >> /home/vagrant/.bashrc

#alias'
