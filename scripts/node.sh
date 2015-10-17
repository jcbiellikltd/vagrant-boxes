#!/bin/bash -eu

echo '==> Installing repos'
yum -y -q install http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
yum-config-manager --enable remi > /dev/null
yum-config-manager --enable remi-php56 > /dev/null
yum-config-manager --add-repo http://repo.jcbiellik.com/jcb.repo > /dev/null
yum-config-manager --enable jcb > /dev/null
yum-config-manager --enable jcb-extra > /dev/null

cat <<-'EOF' > /etc/yum.repos.d/mariadb.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.0/centos6-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

cat <<-'EOF' > /etc/yum.repos.d/mongodb.repo
[mongodb]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.0/x86_64/
gpgcheck=0
EOF

echo '==> Installing HAProxy, Nginx and Ruby'
yum -y -q install haproxy nginx ruby ruby-devel rubygems > /dev/null 2>&1

echo '==> Configuring HAProxy'
cat <<-'EOF' > /etc/haproxy/haproxy.cfg
global
	log         127.0.0.1 local0

	chroot      /var/lib/haproxy
	pidfile     /var/run/haproxy.pid
	maxconn     4000
	user        haproxy
	group       haproxy
	daemon

	stats socket /var/lib/haproxy/stats level admin
	tune.ssl.default-dh-param 2048

defaults
	log                     global
	option                  dontlognull
	option                  redispatch
	option                  tcp-smart-accept
	option                  tcp-smart-connect
	option                  http-server-close
	retries                 3
	timeout http-request    10s
	timeout queue           1m
	timeout connect         10s
	timeout client          1m
	timeout server          1m
	timeout http-keep-alive 10s
	timeout check           10s
	maxconn                 3000

frontend http
	bind :80
	mode http
	option httplog
	option forwardfor

	default_backend nginx

backend nginx
	mode http

	server nginx 127.0.0.1:8080 check send-proxy

listen stats
	bind :9000
	mode http
	stats uri /
	stats scope http
	stats scope nginx
	stats realm HAProxy
	stats auth admin:password
	stats admin if TRUE
EOF

echo '==> Configuring Nginx'
cat <<-'EOF' > /etc/nginx/nginx.conf
user nginx;
worker_processes 1;
worker_rlimit_nofile 40000;

error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
	worker_connections 1024;
	multi_accept on;
	use epoll;
}

http {
	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	log_format main '$remote_addr - $remote_user [$time_local] [$host] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"';
	access_log /var/log/nginx/access.log main;

	charset utf-8;
	sendfile off;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 15;

	set_real_ip_from 127.0.0.1;
	real_ip_header X-Forwarded-For;

	port_in_redirect off;
	server_name_in_redirect off;

	index index.php index.html;
	autoindex on;

	gzip on;
	gzip_disable "msie6";
	gzip_vary on;
	gzip_proxied any;
	gzip_comp_level 6;
	gzip_buffers 16 8k;
	gzip_http_version 1.1;
	gzip_types text/plain text/css text/xml application/xml application/javascript application/atom+xml application/rss+xml application/json;

	client_max_body_size 25m;

	server_tokens off;
	more_set_headers "X-Server: $hostname";
	more_clear_headers 'X-Powered-By' 'Server';

	map $http_x_forwarded_proto $fe_https {
		default off;
		https on;
	}

	include /etc/nginx/conf.d/*.conf;
}

EOF
cat <<-'EOF' > /etc/nginx/conf.d/default.conf
server {
	listen 8080 proxy_protocol default_server; # Catch all
	server_name _;
	root /vagrant/webroot/;
}

EOF

chkconfig haproxy on
chkconfig nginx on

echo 'gem: --no-ri --no-rdoc' > /root/.gemrc
echo 'gem: --no-ri --no-rdoc' > /home/vagrant/.gemrc

echo '==> Installing Bundler'
gem install bundler > /dev/null

echo '==> Installing NVM'
curl -sS -o- https://raw.githubusercontent.com/creationix/nvm/v0.29.0/install.sh | bash > /dev/null
source /home/vagrant/.bashrc

echo '==> Installing Node'
nvm install stable > /dev/null

echo '==> Installing Bower'
npm install -g bower --silent > /dev/null

echo '==> Installing Grunt'
npm install -g grunt-cli --silent > /dev/null

echo '==> Installing Brunch'
npm install -g brunch --silent > /dev/null

echo '==> Installing Bash Completion scripts'
npm completion > /etc/bash_completion.d/npm
