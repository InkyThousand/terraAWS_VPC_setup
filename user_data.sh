#!/bin/bash

# Comprehensive logging setup
exec > >(tee /var/log/user-data.log) 2>&1
set -x  # Enable debug mode

echo "=== USER DATA SCRIPT START ==="
echo "Script started at: $(date)"
echo "User: $(whoami)"
echo "Working directory: $(pwd)"
echo "================================"

# System info
echo "System information:"
uname -a
cat /etc/os-release

# Network diagnostics
echo "Network configuration:"
ip addr show
ip route show
cat /etc/resolv.conf

# Test connectivity step by step
echo "Testing connectivity:"
echo "1. Testing DNS resolution:"
nslookup amazon.com || echo "DNS resolution failed"

echo "2. Testing ping to 8.8.8.8:"
ping -c 3 8.8.8.8 || echo "Ping to 8.8.8.8 failed"

echo "3. Testing HTTP connectivity:"
curl -v --connect-timeout 10 http://amazon.com || echo "HTTP test failed"

# Package manager test
echo "Testing package manager:"
dnf --version
dnf repolist

echo "Starting package installation at $(date)"
dnf update -y 2>&1 | tee -a /var/log/dnf-update.log
UPDATE_STATUS=$?
echo "DNF update exit status: $UPDATE_STATUS"

echo "Installing packages at $(date)"
dnf install -y httpd php php-mysqli php-json php-gd php-mbstring 2>&1 | tee -a /var/log/dnf-install.log
INSTALL_STATUS=$?
echo "Package installation exit status: $INSTALL_STATUS"

echo "Checking if httpd was installed:"
which httpd
rpm -qa | grep httpd

echo "Starting Apache at $(date)"
systemctl start httpd
HTTPD_START_STATUS=$?
echo "Apache start status: $HTTPD_START_STATUS"

systemctl enable httpd
HTTPD_ENABLE_STATUS=$?
echo "Apache enable status: $HTTPD_ENABLE_STATUS"

echo "Apache service status:"
systemctl status httpd --no-pager

# Create health check page
echo "Creating health check page at $(date)"
echo "OK - $(date)" > /var/www/html/health.html
echo "Health check page created"

# Test local web server
echo "Testing local web server:"
curl -I localhost:80 || echo "Local web server test failed"

# Download and install WordPress
echo "Downloading WordPress at $(date)"
cd /tmp
wget https://wordpress.org/latest.tar.gz 2>&1 | tee -a /var/log/wordpress-download.log
WGET_STATUS=$?
echo "WordPress download status: $WGET_STATUS"

if [ $WGET_STATUS -eq 0 ]; then
    echo "Extracting WordPress..."
    tar xzf latest.tar.gz
    cp -r wordpress/* /var/www/html/
    chown -R apache:apache /var/www/html/
    chmod -R 755 /var/www/html/
    
    # Create WordPress config
    cat > /var/www/html/wp-config.php << 'WPEND'
<?php
define('DB_NAME', '${DB_NAME}');
define('DB_USER', '${DB_USER}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_HOST', '${DB_HOST}');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

$table_prefix = 'wp_';
define('WP_DEBUG', false);

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
?>
WPEND
    echo "WordPress configuration created"
else
    echo "WordPress download failed, creating fallback page"
    cat > /var/www/html/index.html << 'HTMLEND'
<!DOCTYPE html>
<html>
<head><title>WordPress Setup Failed</title></head>
<body>
<h1>WordPress Setup in Progress</h1>
<p>WordPress download failed. Check logs at /var/log/user-data.log</p>
<p>Manual setup may be required.</p>
</body>
</html>
HTMLEND
fi

systemctl restart httpd
echo "Apache restart completed"

# Final status check
echo "Final system status:"
systemctl is-active httpd
netstat -tlnp | grep :80 || ss -tlnp | grep :80
ls -la /var/www/html/

echo "=== USER DATA SCRIPT COMPLETED ==="
echo "Script completed at: $(date)"
echo "All exit statuses - Update: $UPDATE_STATUS, Install: $INSTALL_STATUS, Apache Start: $HTTPD_START_STATUS"