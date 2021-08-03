#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root" 1>&2
	exit 1
fi

lan_ipv4=(
	0.0.0.0/8
	10.0.0.0/8
	100.64.0.0/10
	127.0.0.0/8
	169.254.0.0/16
	172.16.0.0/12
	192.0.0.0/24
	192.0.2.0/24
	192.88.99.0/24
	192.168.0.0/16
	198.18.0.0/15
	198.51.100.0/24
	203.0.113.0/24
	224.0.0.0/4
	240.0.0.0/4
	255.255.255.255/32
)

wan_ifname=$(ip route get 8.8.8.8 | awk -- '{printf $5}')
[ -z $wan_ifname ] && exit

up() {
	sslocal --daemonize --log-without-time --acl /tmp/bypass-china.acl --config /tmp/ss.json --daemonize-pid /tmp/ss.pid
}
down() {
	if [ -s /tmp/ss.pid ]; then
		read sspid </tmp/ss.pid
		kill $sspid
		rm -f /tmp/ss.pid
	fi
}
#有acl还不够必须再加上一个中国路由表，因为流量进入sslocal分流后不会再经过nat表的PREROUTING链而是从OUTPUT链发出所以造成网易云解锁失败，
add_rule() {
	up
	ip -4 route add local 0/0 dev lo table 100
	ip -4 rule add fwmark 0x2333/0x2333 table 100
	ipset create sslan4 hash:net family inet -exist
	iptables -t mangle -N SS
	#iptables -t mangle -A SS -p udp -j LOG --log-prefix '** SUSPECT ** '
	for i in ${lan_ipv4[@]}; do
		ipset add sslan4 $i
	done
	#https://unix.stackexchange.com/questions/383521/find-all-ethernet-interface-and-associate-ip-address
	#for i in $(ip -o -4 addr show | awk -- '{print $4}'); do
	#iptables -t mangle -A SS -d $i -j RETURN
	#done
	iptables -t mangle -A SS -i $wan_ifname -j RETURN
	iptables -t mangle -A SS -m set --match-set sslan4 dst -j RETURN
	iptables -t mangle -A SS -p tcp -s 192.168.1.181 -j TPROXY --tproxy-mark 0x2333/0x2333 --on-ip 127.0.0.1 --on-port 60080
	iptables -t mangle -A SS -p udp -s 192.168.1.181 -j TPROXY --tproxy-mark 0x2333/0x2333 --on-ip 127.0.0.1 --on-port 60080
	iptables -t mangle -A PREROUTING -j SS
	iptables -t nat -A PREROUTING -p udp -s 192.168.1.181 --dport 53 -j REDIRECT --to-ports 60053
}
del_rule() {
	ip -4 route del local 0/0 dev lo table 100
	ip -4 rule del fwmark 0x2333/0x2333 table 100
	iptables -t mangle -D PREROUTING -j SS
	iptables -t mangle -F SS
	iptables -t mangle -X SS
	iptables -t nat -D PREROUTING -p udp -s 192.168.1.181 --dport 53 -j REDIRECT --to-ports 60053
	ipset destroy sslan4
	down
}

$1_rule
