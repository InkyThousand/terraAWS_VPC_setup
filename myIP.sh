#!/bin/bash
# Get public IP and add CIDR notation for single IP
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "my_ip = \"$MY_IP/32\""
