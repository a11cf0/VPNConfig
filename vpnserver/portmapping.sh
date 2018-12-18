#!/bin/bash

#
# Port forwarding script with IPv4 and IPv6 support.
# Скрипт для проброса портов с поддержкой IPv4 и IPv6.
#

set -e

NAME=Portmapping
VERSION=7.0

# Load the network configuration.
# Получаем сетевую конфигурацию.
source "$(dirname $(readlink -f $0))/netconf"

## Functions ##
## Функции ##

# Show usage text.
# Вывод справки.
function print_usage() {
	echo "$NAME $VERSION on $HOSTNAME"
	echo "Usage: $(basename $0) [-6][-D][host [tcp|udp|both] port [extport]"
	echo "-6 enables IPv6 mode."
	echo "-D deletes the specified forwarding rule."
	echo "Hostname resolution is supported."
	echo "You can specify protocol names or port ranges in the form [2000]:[3000] instead of plain port numbers."
}

# IPv4 address validation.
# Проверка формата IPv4-адреса.
function valid_v4_ip() {
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
function resolve_v4() {
	if [[ -z $1 ]]; then
		return 1
	fi
	local ip=$(getent ahostsv4 $1 2> /dev/null | head -1 | awk '{print $1}')

	if [[ -z $ip ]]; then
		echo "Error: No such host." >&2
		return 2
	fi
	echo $ip
}

# port forwarding function.
# Функция проброса портов.
function forward() {
	if [[ $IPV6_MODE -eq 1 ]]; then
		ip6tables ${DEL--I} FORWARD -d $LAN_HOST -p $PROTO --dport $SRV_PORT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
		return
	fi

	iptables -t nat ${DEL--I} PREROUTING -d $EXT_IP -p $PROTO --dport $EXT_PORT -j DNAT --to-destination $LAN_HOST:$SRV_PORT
	iptables -t nat ${DEL--A} POSTROUTING -s $INT_SUBNET -d $LAN_HOST -p $PROTO --dport $SRV_PORT -j SNAT --to-source $INT_IP
	iptables -t nat ${DEL--A} OUTPUT -d $EXT_IP -p $PROTO --dport $EXT_PORT -j DNAT --to-destination $LAN_HOST:$SRV_PORT
	iptables ${DEL--I} FORWARD -d $LAN_HOST -p $PROTO --dport $SRV_PORT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
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
EXT_PORT=${4:-$SRV_PORT}

if [[ $USER != root ]]; then
	echo "Error: This script must be run as root." >&2
	exit 1
fi

if [[ $# -eq 0 || $* == -h || $* == -H || $* == --help ]]; then
	print_usage
	exit 0
elif [[ -z $LAN_HOST || -z $PROTO || -z $SRV_PORT ]]; then
	echo "Error: Required argument is missing." >&2
	ERR=1
elif [[ $PROTO != tcp && $PROTO != udp && $PROTO != both ]]; then
	echo "Error: The specified protocol is incorrect." >&2
	ERR=1
fi

if [[ ! -z $ERR ]]; then
	print_usage >&2
	exit $ERR
fi

if [[ $IPV6_MODE -ne 1 ]] && ! valid_v4_ip $LAN_HOST; then
	LAN_HOST=$(resolve_v4 $LAN_HOST)
fi

if [[ $PROTO == both ]]; then
	PROTOS="tcp udp"
	for PROTO in $PROTOS; do
		forward
	done
else
	forward
fi
