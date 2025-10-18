#!/bin/bash
# Сброс правил
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Политики по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Разрешаем loopback
iptables -A INPUT -i lo -j ACCEPT

# Разрешаем установленные и связанные соединения
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Разрешаем SSH (порт 22222 например)
iptables -A INPUT -p tcp --dport 22222 -j ACCEPT

# Разрешаем VLESS
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Разрешаем порт панели 3X-UI (Если необходимо)
#iptables -A INPUT -p tcp --dport <3X-UI_WEB_PORT> -j ACCEPT

# Разрешаем ICMP с ограничением
iptables -A INPUT -p icmp -m limit --limit 1/second -j ACCEPT

# Разрешаем FORWARD для Xray (VLESS + Reality)
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -p tcp -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -p udp -m conntrack --ctstate NEW -j ACCEPT

# NAT: Маскировка исходящего трафика (Заменить eth0, если интерфейс отличается)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Сохраняем правила
sudo netfilter-persistent save

# Сохраняем IP forwarding навсегда
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Вывод для проверки
iptables -L -v -n
iptables -t nat -L -v -n