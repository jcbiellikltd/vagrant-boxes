# Vagrant Boxes [![License](https://img.shields.io/badge/license-MIT-brightgreen.svg)](http://jcbiellik.com/license) [![Release Version](https://img.shields.io/github/release/jcbiellikltd/vagrant-boxes.svg)](https://github.com/jcbiellikltd/vagrant-boxes/releases) [![Packer Version](https://img.shields.io/badge/packer-v0.8.5-yellow.svg)](https://packer.io/) [![VirtualBox Version](https://img.shields.io/badge/virtualbox-v4.3.30-red.svg)](https://www.virtualbox.org/)

[CentOS](https://www.centos.org/) boxes for use with [Vagrant](https://www.vagrantup.com/).

Usage
--------

You can [download the boxes directly](http://repo.jcbiellik.com/boxes/) or [from Atlas](https://atlas.hashicorp.com/jcbiellikltd), [build them yourself](#building) or simply reference them in your [Vagrantfile](Vagrantfile-base):
```sh
config.vm.box = "jcbiellikltd/centos-6-base"
# or
config.vm.box = "jcbiellikltd/centos-6-web"
```

Building
--------

Building these boxes requires [Packer](https://packer.io/) and [VirtualBox](https://www.virtualbox.org/) to be installed.

1. Clone this repo:
	```sh
	git clone https://github.com/jcbiellikltd/vagrant-boxes.git
	cd vagrant-boxes
	```

2. Build a box:
	```sh
	BUILD_VERSION=vX.X.X packer build centos-6-XXX.json
	```
