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

echo '==> Installing HAProxy, Nginx and PHP 5.6, MariaDB and extra tools'
yum -y -q install haproxy nginx php-fpm php-mcrypt php-intl php-mbstring php-xml php-bcmath php-pdo php-soap php-mysqlnd php-process php-pecl-memcache php-pecl-memcached php-pecl-mongo php-gd php-xdebug php-pecl-imagick MariaDB-server MariaDB-client gd ImageMagick npm libpng-devel ruby ruby-devel rubygems wkhtmltox > /dev/null 2>&1

ln -s /usr/local/bin/wkhtmltopdf /usr/bin/wkhtmltopdf

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

listen mysql :3306
	mode tcp
	option tcplog

	server mariadb 127.0.0.1:3307

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
cat <<-'EOF' > /etc/nginx/conf.d/php.inc
location / {
	try_files $uri $uri/ /index.php?$args;
}

location ~ \.php$ {
	try_files $uri =404;
	include /etc/nginx/fastcgi_params;
	fastcgi_pass unix:/var/run/php-fpm.sock;
	fastcgi_index index.php;
	fastcgi_intercept_errors on;
	fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
	fastcgi_param DEBUG 1;
}

EOF
cat <<-'EOF' > /etc/nginx/conf.d/default.conf
server {
	listen 8080 proxy_protocol default_server; # Catch all
	server_name _;
	root /vagrant/webroot/;

	include conf.d/php.inc;
}

EOF

echo '==> Configuring PHP'
echo -e "\n; Development settings\ndate.timezone = UTC\ndisplay_errors = On" >> /etc/php.ini
chown -R root:vagrant /var/lib/php/session
cat <<-'EOF' > /etc/php-fpm.d/www.conf
[www]
listen = /var/run/php-fpm.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0660

user = vagrant
group = vagrant

pm = dynamic
pm.max_children = 8
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 2
pm.max_requests = 10000

pm.status_path = /status
ping.path = /ping

request_slowlog_timeout = 5s
slowlog = /var/log/php-fpm/www-slow.log
rlimit_files = 131072
rlimit_core = unlimited

php_admin_value[error_log] = /var/log/php-fpm/www-error.log
php_admin_flag[log_errors] = on
php_value[session.save_handler] = files
php_value[session.save_path] = /var/lib/php/session

EOF

echo '==> Configuring MariaDB'
cat <<-'EOF' > /etc/my.cnf.d/server.cnf
[server]
bind-address=0.0.0.0
port=3307

[mysqld]
[embedded]
[mariadb]
[mariadb-10.0]

EOF

service mysql start

mysql -u root <<-EOF
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF

chkconfig haproxy on
chkconfig nginx on
chkconfig php-fpm on
chkconfig mysql on

echo 'gem: --no-ri --no-rdoc' > /root/.gemrc
echo 'gem: --no-ri --no-rdoc' > /home/vagrant/.gemrc

echo '==> Installing Bundler'
gem install bundler > /dev/null

echo '==> Installing Composer'
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer > /dev/null
su vagrant -c '/usr/local/bin/composer config --global process-timeout 600'

echo '==> Installing Bower'
npm install -g bower --silent > /dev/null

echo '==> Installing Grunt'
npm install -g grunt-cli --silent > /dev/null

echo '==> Installing PHPUnit'
curl -sS https://phar.phpunit.de/phpunit.phar > /usr/local/bin/phpunit
chmod +x /usr/local/bin/phpunit

echo '==> Installing MaxMind GeoIP database'
mkdir -p /etc/GeoIP
curl -sS http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz | gzip -d > /etc/GeoIP/GeoLite2-City.mmdb
chown -R apache:apache /etc/GeoIP

echo '==> Installing Bash Completion scripts'
cat <<-'EOF' > /etc/bash_completion.d/cakephp
# bash completion for CakePHP console

_cake()
{
	local cur prev opts cake
	COMPREPLY=()
	cake="${COMP_WORDS[0]}"
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"

	if [[ "$cur" == -* ]] ; then
		if [[ ${COMP_CWORD} = 1 ]] ; then
			opts=$(${cake} Completion options)
		elif [[ ${COMP_CWORD} = 2 ]] ; then
			opts=$(${cake} Completion options "${COMP_WORDS[1]}")
		else
			opts=$(${cake} Completion options "${COMP_WORDS[1]}" "${COMP_WORDS[2]}")
		fi

		COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
		return 0
	fi

	if [[ ${COMP_CWORD} = 1 ]] ; then
		opts=$(${cake} Completion commands)
		COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
		return 0
	fi

	if [[ ${COMP_CWORD} = 2 ]] ; then
		opts=$(${cake} Completion subcommands $prev)
		COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
		if [[ $COMPREPLY = "" ]] ; then
			COMPREPLY=( $(compgen -df -- ${cur}) )
			return 0
		fi
		return 0
	fi


	opts=$(${cake} Completion fuzzy "${COMP_WORDS[@]:1}")
	COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
	if [[ $COMPREPLY = "" ]] ; then
		COMPREPLY=( $(compgen -df -- ${cur}) )
		return 0
	fi
	return 0;
}

complete -F _cake cake bin/cake

EOF

cat <<-'EOF' > /etc/bash_completion.d/composer
# bash completion for Composer

_composer()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    local cmd=${COMP_WORDS[0]}
    if ($cmd > /dev/null 2>&1)
    then
        COMPREPLY=( $(compgen -W "$($cmd list --raw | cut -f 1 -d " " | tr "\n" " ")" -- $cur) )
    fi
}
complete -F _composer composer
complete -F _composer composer.phar

EOF

npm completion > /etc/bash_completion.d/npm
