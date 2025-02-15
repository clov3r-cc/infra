#!/bin/bash

### Run as root
if [ "$(id -u)" -ne 0 ]; then
  echo 'This script must be run as root'
  exit 1
fi

### Enable IP forwarding

echo '1' >/proc/sys/net/ipv4/ip_forward

if [ "$(/sbin/sysctl net.ipv4.ip_forward | awk '{print $3}')" -eq 0 ]; then
  sed -i '/^net\.ipv4\.ip_forward/d' /etc/sysctl.conf
  echo "net.ipv4.ip_forward = 1" >>/etc/sysctl.conf
fi

### Enable NAT

cat <<EOF >/tmp/ruleset.nft
# Translated by iptables-restore-translate v1.8.10 on Sat Feb 15 10:37:11 2025
add table ip nat
add rule ip nat POSTROUTING oifname "eth0" counter masquerade
add table ip filter
add rule ip filter INPUT iifname "lo" counter accept
# Allow SSH, HTTP, HTTPS, and Kubernetes API Server
add rule ip filter INPUT iifname "eth0" tcp dport 22 counter accept
add rule ip filter INPUT iifname "eth0" tcp dport 80 counter accept
add rule ip filter INPUT iifname "eth0" tcp dport 443 counter accept
add rule ip filter INPUT iifname "eth0" tcp dport 6443 counter accept
add rule ip filter INPUT iifname "eth0" ip protocol icmp counter accept
# Allow incoming traffic to the outgoing connections,
# et al for clients from the private network
add rule ip filter INPUT ct state related,established counter accept
# Drop all other incoming traffic
add rule ip filter INPUT iifname "eth0" counter drop
# Completed on Sat Feb 15 10:37:11 2025
EOF
nft -f /tmp/ruleset.nft
rm -f /tmp/ruleset.nft

systemctl reboot
