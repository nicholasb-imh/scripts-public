#!/bin/bash

install_nginx() {
  yum -y install epel-release imh-python imh-ngxconf imh-ngxutil imh-cpanel-cache-manager
# add X-Real-IP to Apache's log entries    
cat << EOF >> /etc/apache2/conf.d/includes/pre_virtualhost_global.conf

<IfModule log_config_module>
  LogFormat "%{X-Real-IP}i %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
</IfModule>
<IfModule log_config_module>
  ErrorLogFormat "[%{u}t] [%-m:%l] [pid %P:tid %T] %7F: %E: [client\ %{X-Real-IP}i] %M% ,\ referer\ %{Referer}i"
</IfModule>
EOF
# add service monitoring check
  sed -i 's/apache_port=.*/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
  sed -i 's/apache_ssl_port=.*/apache_ssl_port=0.0.0.0:8443/' /var/cpanel/cpanel.config
  sed -i '/accel_static_content/s/true/false/' /home*/*/.imh/nginx/*.yml
  sed -i '/enable_fpm/s/true/false/' /opt/ngxconf/config.yaml
  /scripts/rebuildhttpdconf
  /scripts/restartsrv_httpd
  ngxconf -Rrd
  service nginx start
  /scripts/restartsrv_apache_php_fpm
  netstat -nlp|grep -P 'nginx|httpd'
}

uninstall_nginx() {
    sed -i 's/apache_port=.*/apache_port=0.0.0.0:80/' /var/cpanel/cpanel.config
    sed -i 's/apache_ssl_port=.*/apache_ssl_port=0.0.0.0:443/' /var/cpanel/cpanel.config
    service cpanel restart
    /scripts/rebuildhttpdconf
    /scripts/restartsrv_httpd
    yum -y remove imh-ngxconf imh-ngxutil imh-cpanel-cache-manager imh-nginx
    service httpd restart
    /scripts/php_fpm_config --rebuild
    /scripts/restartsrv_apache_php_fpm
    netstat -nlp|grep -P 'nginx|httpd'
}
#Takes user input and performs one of the 2 functions (install or uninstall NGINX).
printf '\nThis script will install or uninstall NGINX.\nIt will also automatically change Apache ports and user agents to work with NGINX as a proxy.\n\nIf you notice any issues with this script please let me know.\nAuthor: NicholasB\n\nOptions:\n'
PS3='Select an option and press Enter: '
options=("Install NGINX" "Uninstall NGINX" "Cancel")
select opt in "${options[@]}"
do
    case $opt in 
        "Install NGINX")
            install_nginx
            break
            ;;
        "Uninstall NGINX")
            uninstall_nginx
            break
            ;;
        "Cancel")
            break
            ;;
        *) echo "Option invalid, please enter 1 or 2.";;
    esac
done
echo "Have a nice day!"
