#!/bin/bash -eu

echo '==> Applying slow DNS fix'
# https://github.com/mitchellh/vagrant/issues/1172#issuecomment-9438465
echo 'RES_OPTIONS="single-request-reopen"' >> /etc/sysconfig/network
service network restart > /dev/null
