 #!/bin/bash

# # Quick connectivity test
# if ! ping 8.8.8.8; then
#     echo "No internet connectivity - checking network config:"
#     ip route
#     cat /etc/resolv.conf
#     sleep 30
# fi
    
dnf update -y
dnf install -y httpd php php-mysqli php-json php-gd php-mbstring
    
systemctl start httpd
systemctl enable httpd
    
# Create a simple health check page first
echo "OK" > /var/www/html/health.html

# Download and extract WordPress
cd /tmp
wget https://wordpress.org/latest.zip -O /tmp/wordpress.zip
unzip /tmp/wordpress.zip -d /tmp/
cp -r /tmp/wordpress/* /var/www/html/
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# Configure wp-config.php
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i "s/database_name_here/${DB_NAME}/" /var/www/html/wp-config.php
sed -i "s/username_here/${DB_USER}/" /var/www/html/wp-config.php
sed -i "s/password_here/${DB_PASSWORD}/" /var/www/html/wp-config.php
sed -i "s/host_here/${DB_HOST}/" /var/www/html/wp-config.php
