#!/bin/bash -eu

echo '==> Configuring SSH options...'

echo '==> Turning off DNS lookup'
echo 'UseDNS no' >> /etc/ssh/sshd_config
echo '==> Disablng GSSAPI authentication'
echo 'GSSAPIAuthentication no' >> /etc/ssh/sshd_config
