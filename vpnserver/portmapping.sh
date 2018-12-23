#!/bin/bash

#
# Port forwarding script with IPv4 and IPv6 support.
# Скрипт для проброса портов с поддержкой IPv4 и IPv6.
#

set -euo pipefail

# Load the network configuration.
# Получаем сетевую конфигурацию.
source "$(dirname $(readlink -f $0))/netconf"

## Globals ##
## Глобальные переменные ##

SCRIPT_NAME="Portmapping"
SCRIPT_VERSION="8.0"

IPV6_MODE=0
VERBOSE=0
FORCE=0
FWD_OPT=""

## Functions ##
## Функции ##

# Show usage text and exit.
# Вывод справки и выход.
function print_usage() {
	cat <<-EOF >&2
	$SCRIPT_NAME $SCRIPT_VERSION on $(hostname)
	Usage: $(basename $0) [OPTION]... [HOST [tcp|udp|both] PORT [EXTPORT]]
	
	-6 enables IPv6 mode (doesn't support port redirection)
	-D deletes the specified forwarding rule
	-f skips all rule checks
	-v enables verbose output
	-h or -H prints this help
	
	Hostname resolution is supported.
	You can specify protocol names or port ranges in the form [2000]:[3000] instead of plain port numbers.
	EOF
	exit 2
}

# IPv4 address validation.
# Проверка формата IPv4-адреса.
function valid_v4_ip() {
	local ip stat

	if [[ -z "$@" ]]; then
		return 1
	fi

	ip="$1"
	stat=1

	if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS="$IFS"
		IFS="."
		ip=($ip)
		IFS="$OIFS"
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
			&& ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	fi
	return $stat
}

# Hostname resolution function for IPv4.
# Функция разрешения доменных имен для IPv4.
function resolve_v4() {
	local ip

	if [[ -z "$@" ]]; then
		return 1
	fi

	ip=$(getent ahostsv4 $1 2> /dev/null | head -1 | awk '{print $1}')

	if [[ -z "$ip" ]]; then
		echo "Error: No such host." >&2
		return 2
	fi
	echo "$ip"
}

# For verbose output. Echo a command befor execution.
# Функция подробного вывода. Вывод команды перед выполнением.
function vexec() {
	if [[ -z "$@" ]]; then
		return 1
	fi

	if [[ $VERBOSE -eq 1 ]]; then
		echo "$@" >&2
	fi
	eval "$@"
}

# Check if iptables rules exist.
# Функция для проверки существования правил iptables.
function check_rules() {
	local result

	if [[ $FORCE -eq 1 ]]; then
		return
	fi

	result=1

	if forward -C > /dev/null 2>&1 ; then
		result=0
	fi
	if [[ "$@" == "-D" ]]; then
		if [[ $result -ne 0 ]]; then
			echo "Error: No such rule." >&2
		fi
		return $result
	fi
	result=$(( result ^= 1 ))
	if [[ $result -ne 0 ]]; then
		echo "Error: Rule already exists." >&2
	fi
	return $result
}

# port forwarding function.
# Функция проброса портов.
function forward() {
	if [[ $IPV6_MODE -eq 1 ]]; then
		vexec ip6tables "${1:--I}" FORWARD -d "$LAN_HOST" -p "$PROTO" --dport "$SRV_PORT" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
		return
	fi
	vexec iptables -t nat "${1:--I}" PREROUTING -d "$EXT_IP" -p "$PROTO" --dport "$EXT_PORT" -j DNAT --to-destination "$LAN_HOST":"$SRV_PORT" && \
	vexec iptables -t nat "${1:--A}" POSTROUTING -s "$INT_SUBNET" -d "$LAN_HOST" -p "$PROTO" --dport "$SRV_PORT" -j SNAT --to-source "$INT_IP" && \
	vexec iptables -t nat "${1:--A}" OUTPUT -d "$EXT_IP" -p "$PROTO" --dport "$EXT_PORT" -j DNAT --to-destination "$LAN_HOST":"$SRV_PORT" && \
	vexec iptables "${1:--I}" FORWARD -d "$LAN_HOST" -p "$PROTO" --dport "$SRV_PORT" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
}

## Main code ##
## Основной код ##

if [[ $EUID -ne 0 ]]; then
	echo "Error: This script must be run as root." >&2
	exit 1
fi

if [[ -z "$@" ]]; then
	print_usage
fi

while getopts ":6DfvhH" OPT; do
	case "$OPT" in
		6)
		IPV6_MODE=1
		;;
		D)
		FWD_OPT="-D"
		;;
		f)
		FORCE=1
		;;
		v)
		VERBOSE=1
		;;
		h|H)
		print_usage
		;;
		?)
		echo "Error: Invalid option $1." >&2
		print_usage
		;;
	esac
done
shift $((OPTIND - 1))

if [[ $# -lt 3 ]]; then
	echo "Error: Required argument is missing." >&2
	print_usage
fi

LAN_HOST="$1"
PROTOS="$2"
SRV_PORT="$3"
EXT_PORT="${4:-$SRV_PORT}"

if [[ $IPV6_MODE -ne 1 ]] && ! valid_v4_ip "$LAN_HOST"; then
	LAN_HOST=$(resolve_v4 "$LAN_HOST")
fi

if [[ "$PROTOS" == "both" ]]; then
	PROTOS="tcp udp"
elif [[ "$PROTOS" != "tcp" && "$PROTOS" != "udp" ]]; then
	echo "Error: Protocol is incorrect." >&2
	print_usage
fi

for PROTO in $PROTOS; do
	check_rules "$FWD_OPT"
	forward "$FWD_OPT"
done
