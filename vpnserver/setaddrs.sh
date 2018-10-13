#!/bin/bash

#
# This Script assigns addresses to the VPN TAP interface.
# Скрипт для присвоения адресов TAP-интерфейсу VPN.
#

# Load the network configuration.
# Получаем сетевую конфигурацию.
source $(dirname $(readlink -f $0))/netconf

ifconfig $INT_IF $INT_IP

# IPv6
if [[ $IPV6 -eq 1 ]]; then
	ifconfig $INT_IF inet6 add $INT_V6_IP/$INT_V6_PREFLEN
fi
