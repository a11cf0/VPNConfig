#!/bin/bash

#
# Port forwarding script with IPv4 and IPv6 support.
# Скрипт для проброса портов с поддержкой IPv4 и IPv6.
#

NAME=Portmapping
VERSION=5.5

# Load the network configuration.
# Получаем сетевую конфигурацию.
source "$(dirname $(readlink -f $0))/netconf"

## Functions ##
## Функции ##

# Show usage text.
# Вывод справки.
print_usage() {
	echo "$NAME $VERSION on $HOSTNAME"
	echo "Usage: $(basename $0) [-6][-D][host [tcp|udp] port"
	echo "-6 enables IPv6 mode."
	echo "-D deletes the specified forwarding rule."
	echo "Hostnname resolution is supported."
	echo "You can specify a protocol or a port range in the form [2000]:[3000] instead of a single port number."
}

# IPv4 address validation.
# Проверка формата IPv4-адреса.
valid_v4_ip() {
	local ip=$1
	local stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=$IFS
		IFS='.'
		ip=($ip)
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
			&& ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	fi
	return $stat
}

# Hostname resolution function for IPv4.
# Функция разрешения доменных имен для IPv4.
resolve_v4() {
	if [[ -z $1 ]]; then
		return 1
	fi
	local ip=$(getent ahostsv4 $1 | head -1 | awk '{print $1}')

	if [[ -z $ip ]]; then
		echo "Error: No such host." >&2
		return 2
	fi
	echo $ip
}

# IPv4 port forwarding.
# Функция для проброса портов IPv4.
forward_v4() {
	iptables -t nat ${DEL--I} PREROUTING -d $EXT_IP -p $PROTO --dport $SRV_PORT -j DNAT --to-destination $LAN_HOST
	iptables -t nat ${DEL--A} POSTROUTING -s $INT_SUBNET -d $LAN_HOST -p $PROTO --dport $SRV_PORT -j SNAT --to-source $INT_IP
	iptables -t nat ${DEL--A} OUTPUT -d $EXT_IP -p $PROTO --dport $SRV_PORT -j DNAT --to-destination $LAN_HOST
	iptables ${DEL--I} FORWARD -d $LAN_HOST -p $PROTO --dport $SRV_PORT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
}

# IPv6 forwarding.
# Функция для проброса IPv6.
forward_v6() {
	ip6tables ${DEL--I} FORWARD -d $LAN_HOST -p $PROTO --dport $SRV_PORT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
}

## Main code ##
## Основной код ##

if [[ $1 == -6 ]]; then
	IPV6_MODE=1
	shift
fi
if [[ $1 == -D ]]; then
	DEL=$1
	shift
fi

LAN_HOST=$1
PROTO=$2
SRV_PORT=$3

if [[ $USER != root ]]; then
	echo "Error: This script must be run as root." >&2
	exit 1
fi

if [[ $# -eq 0 ]]; then
	print_usage
	exit 0
elif [[ $# -ne 3 || $PROTO != tcp && $PROTO != udp ]]; then
	echo "Error: Bad arguments supplied." >&2
	print_usage >&2
	exit 1
fi

if [[ $IPV6_MODE -eq 1 ]]; then
	forward_v6
elif valid_v4_ip $LAN_HOST; then
	forward_v4
else
	LAN_HOST=$(resolve_v4 $LAN_HOST)
	forward_v4
fi
