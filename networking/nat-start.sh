#!/bin/sh
iptables -t nat -I VSERVER 1 -p tcp -m tcp -s 10.10.10.10 --dport 3389 -j DNAT --to 192.168.1.100

# port blocking

# iptables -A INPUT -p tcp --destination-port {PORT-NUMBER-HERE} -j DROP

# wanacrypte port 445 139 3389 ransomware

iptables -A INPUT -p tcp --destination-port 445 -j DROP
iptables -A INPUT -p tcp --destination-port 139 -j DROP
iptables -A INPUT -p tcp --destination-port 3389 -j DROP

# portmapper explote 111

iptables -A INPUT -p tcp --destination-port 111 -j DROP
iptables -A INPUT -p udp --destination-port 111 -j DROP

