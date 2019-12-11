for i in $(find -name xmlrpc.php /home | awk -F 'xmlrpc.php' '{print $1}') 
do cat << EOF >> .htaccess
# Block WordPress xmlrpc.php requests
<Files xmlrpc.php>
order deny,allow
deny from all
</Files>
EOF
done
