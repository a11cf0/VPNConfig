#!/bin/bash

#
# This Script assigns addresses to the VPN TAP interface.
# It should be run after the interface is up.
# Скрипт для присвоения адресов TAP-интерфейсу VPN.
# Должен запускаться после его поднятия.
#

set -euo pipefail

# Load the network configuration.
# Получаем сетевую конфигурацию.
source "$(dirname $(readlink -f $0))/netconf"

ip address add "$INT_IP"$(echo "$INT_SUBNET" | grep -Po '/\d+$') broadcast + dev "$INT_IF"

# IPv6
if [[ $IPV6 -eq 1 ]]; then
	ip -6 address add "$INT_V6_IP"/"$INT_V6_PREFLEN" dev "$INT_IF"
fi
