#!/bin/bash

set -euo pipefail

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

cat <<EOF >/etc/nftables/ip-routing.nft
# Translated by iptables-restore-translate v1.8.10 on Sat Feb 15 10:37:11 2025
add table ip nat
add chain nat prerouting { type nat hook prerouting priority -100; }
add chain nat postrouting { type nat hook postrouting priority 100; }
add rule ip nat postrouting oifname "eth0" counter masquerade
add table ip filter
add chain ip filter input { type filter hook input priority 0; }
add rule ip filter input iifname "lo" counter accept
# Allow SSH, HTTP, HTTPS, and Kubernetes API Server
add rule ip filter input iifname "eth0" tcp dport 22 counter accept
add rule ip filter input iifname "eth0" tcp dport 80 counter accept
add rule ip filter input iifname "eth0" tcp dport 443 counter accept
add rule ip filter input iifname "eth0" tcp dport 6443 counter accept
add rule ip filter input iifname "eth0" ip protocol icmp counter accept
# Allow incoming traffic to the outgoing connections,
# et al for clients from the private network
add rule ip filter input ct state related,established counter accept
# Drop all other incoming traffic
add rule ip filter input iifname "eth0" counter drop
# Completed on Sat Feb 15 10:37:11 2025
EOF

if [ ! -f /etc/sysconfig/nftables.conf ] || ! grep -q 'include "/etc/nftables/ip-routing.nft"' /etc/sysconfig/nftables.conf; then
  echo 'include "/etc/nftables/ip-routing.nft"' >>/etc/sysconfig/nftables.conf
fi

systemctl enable nftables
systemctl restart nftables
