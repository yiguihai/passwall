#!/bin/bash

#set -e

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

acl() {
	if [ ! -s /tmp/bypass-china.acl ]; then
		cat >/tmp/bypass-china.acl <<EOF
[proxy_all]

[bypass_list]
#第五人格防止跳国外服务器
(?:^|\.)netease\.com$
(?:^|\.)easebar\.com$
$(curl -s https://bgp.space/china.html | grep -oE '([0-9]+\.){3}[0-9]+?\/[0-9]{1,2}')
$(curl -s https://bgp.space/china6.html | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}\/[0-9]{1,3}')
EOF
	fi
}
up() {
	sslocal --daemonize --log-without-time --acl /tmp/bypass-china.acl --config /root/ss.json --daemonize-pid /tmp/ss.pid
	sleep 2
}
down() {
	if [ -s /tmp/ss.pid ]; then
		read sspid </tmp/ss.pid
		kill $sspid
	fi
}

add_rule() {
	acl
	up
	ip -4 route add local 0/0 dev lo table 100
	ip -4 rule add fwmark 0x2333/0x2333 table 100
	#https://m.itbiancheng.com/linux/4961.html
	ipset create sslan4 hash:net family inet -exist
	iptables -w -t mangle -N SS
	#iptables -w -t mangle -A SS -p udp -j LOG --log-prefix '** SUSPECT ** '
	for i in ${lan_ipv4[@]}; do
		ipset add sslan4 $i
	done
	if [ ! -s /tmp/chnip.ipset ]; then
		#流量没有经过nat表的PREROUTING链而是进入mangle表PREROUTING链后直接进入sslocal没有经过定向就被发出了所以造成网易云解锁失败
		echo "正在添加ipset规则..."
		ipset create chnip hash:net family inet -exist
		for i in $(curl -s https://proxy.freecdn.workers.dev/?url=https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt | grep -oE '([0-9]+\.){3}[0-9]+?\/[0-9]{1,2}'); do
			ipset add chnip $i
		done
		ipset save chnip -f /tmp/chnip.ipset
	else
		ipset restore -f /tmp/chnip.ipset
	fi
	#https://unix.stackexchange.com/questions/383521/find-all-ethernet-interface-and-associate-ip-address
	#for i in $(ip -o -4 addr show | awk -- '{print $4}'); do
	#iptables -w -t mangle -A SS -d $i -j RETURN
	#done
	iptables -w -t mangle -A SS -i $wan_ifname -j RETURN
	iptables -w -t mangle -A SS -m set --match-set sslan4 dst -j RETURN
	iptables -w -t mangle -A SS -m set --match-set chnip dst -j RETURN
	iptables -w -t mangle -A SS -p tcp -s 192.168.1.181 -j TPROXY --tproxy-mark 0x2333/0x2333 --on-ip 127.0.0.1 --on-port 60080
	iptables -w -t mangle -A SS -p udp -s 192.168.1.181 -j TPROXY --tproxy-mark 0x2333/0x2333 --on-ip 127.0.0.1 --on-port 60080
	iptables -w -t mangle -A PREROUTING -j SS
	iptables -w -t nat -A PREROUTING -p udp -s 192.168.1.181 --dport 53 -j REDIRECT --to-ports 60053
}
del_rule() {
	ip -4 route del local 0/0 dev lo table 100
	ip -4 rule del fwmark 0x2333/0x2333 table 100
	iptables -w -t mangle -D PREROUTING -j SS
	iptables -w -t mangle -F SS
	iptables -w -t mangle -X SS
	iptables -w -t nat -D PREROUTING -p udp -s 192.168.1.181 --dport 53 -j REDIRECT --to-ports 60053
	ipset destroy sslan4
	ipset destroy chnip
	down
}

$1_rule
