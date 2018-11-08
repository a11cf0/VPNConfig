#!/bin/bash

#
# This script configures the firewall for VPN compatibility.
# Скрипт настройки файрвола для VPN.
# If you're using CSF, create a symlink to this file at
# /etc/csf/csfpost.sh
# Otherwise configure your system to run this script on boot or at firewall start.
# Если используете CSF, создайте символьную ссылку на этот файл по пути
# /etc/csf/csfpost.sh
# Иначе, настройте автозапуск этого скрипта при загрузке или при старте фаервола.
# Custom commands can be added at the end of this file.
# Возможно добавление своих команд в конец этого файла.
#

# Load the network configuration.
# Получаем сетевую конфигурацию.
source $(dirname $(readlink -f $0))/netconf

# Forward everything from the virtual LAN and all other established connections.
# Разрешаем проброс трафика из локальной сети и для уже установленных соединений, а остальной запрещаем.
iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $INT_IF -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -j REJECT

# We want VPN users connecting to the public IPv4 address of this server
# to be redirected back to the local address.
# Перенаправляем клиентов локальной сети, подключающихся к серверу по внешнему адресу,
# на его же локальный адрес.
iptables -t nat -A PREROUTING -s $INT_SUBNET -d $EXT_IP -j DNAT --to-destination $INT_IP

# Configure NAT so that VPN users can access the IPv4 Internet.
# Пускаем клиентов виртуальной локальной сети в интернет.
iptables -t nat -A POSTROUTING -s $INT_SUBNET -o $EXT_IF -j SNAT --to-source $EXT_IP

# IPv6
if [[ $IPV6 -eq 1 ]]; then
	# Forwarding rules are almost the same as for IPv4.
	# правила проброса трафика. См. выше.
	ip6tables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
	ip6tables -A FORWARD -i $INT_IF -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
	ip6tables -A FORWARD -j REJECT

	# If IPv6 is provided by a tunnel broker, the 6in4 encapsulation protocol should be allowed to pass through.
	# При использовании туннельного брокера IPv6 разрешаем протокол инкапсуляции IPv6 в IPv4.
	if [[ $IPV6_TUN -eq 1 ]]; then
		iptables -I INPUT -p ipv6 -j ACCEPT
		iptables -I OUTPUT -p ipv6 -j ACCEPT
	fi

	# Clients outside our IPv6 subnet shoudn't have acces to internal services like DNS.
	# Запрещаем внешним клиентам подключаться к нашему серверу по IPv6-адресу внутренних ресурсов.
	ip6tables -I INPUT -i !$INT_IF -d $INT_V6_IP -j REJECT
fi
