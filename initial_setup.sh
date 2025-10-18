#!/bin/bash

#Конфигурация
ALLOW_ROOT_SSH=true    # true = разрешить root (например, в облаке), false = запретить root
SSH_PORT=22222         # SSH порт
BAN_TIME=7d            # Время бана в fail2ban (пример: 10m, 1h, 1d)

# Обновление пакетов
sudo apt-get update && sudo apt-get upgrade -y


# Установка основного набора утилит
sudo apt install -y \
    htop iotop bmon ncdu tmux smartmontools \
    auditd bash-completion logrotate \
    curl wget git net-tools traceroute unzip tar \
    nano mc iproute2 dnsutils lm-sensors vnstat lshw iputils-ping \

setup_iptables() {
    echo "[INFO] Setup iptables..."
    sudo apt install -y iptables-persistent netfilter-persistent
	
	echo "[INFO] Creating iptables-rules.sh script..."
 cat << EOF > iptables-rules.sh
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

# Разрешаем установленные соединения
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Разрешаем SSH
iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT

# Разрешаем Zabbix
#iptables -A INPUT -p tcp --dport 10050 -j ACCEPT

# Разрешаем HTTP/HTTPS
#iptables -A INPUT -p tcp --dport 80 -j ACCEPT
#iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Разрешаем ICMP с ограничением
iptables -A INPUT -p icmp -m limit --limit 1/second -j ACCEPT

# Сохраняем правила
sudo netfilter-persistent save
EOF

	echo "[INFO] Applying iptables rules..."
	sudo chmod +x iptables-rules.sh
	sudo ./iptables-rules.sh
    echo "[INFO] Firewall setup completed successfully."
}

setup_fail2ban() {
    echo "[INFO] Setup fail2ban..."
    sudo apt-get install -y fail2ban
    echo "[INFO] Setup fail2ban sshd..."

    cat << EOF > /etc/fail2ban/jail.d/sshd.conf
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = $BAN_TIME
findtime = 300
EOF

    sudo systemctl enable --now fail2ban
    echo "[INFO] fail2ban setup completed."
}

setup_ssh() {
    echo "[INFO] Setting up SSH configuration..."

    # Отключаем ssh socket
	echo "[INFO] Disabling an SSH socket"
    sudo systemctl stop ssh.socket
    sudo systemctl disable ssh.socket
    sudo systemctl mask ssh.socket
    sudo systemctl enable --now ssh.service

    echo "[INFO] Backing up /etc/ssh/sshd_config..."
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    echo "[INFO] Configuring /etc/ssh/sshd_config..."
	
    # Комментируем существующие настройки
    sudo sed -i 's/^Port .*/#&/' /etc/ssh/sshd_config
    sudo sed -i 's/^PermitRootLogin .*/#&/' /etc/ssh/sshd_config
    sudo sed -i 's/^PasswordAuthentication .*/#&/' /etc/ssh/sshd_config
    sudo sed -i 's/^PubkeyAuthentication .*/#&/' /etc/ssh/sshd_config
    sudo sed -i 's/^Protocol .*/#&/' /etc/ssh/sshd_config
    sudo sed -i 's/^MaxAuthTries .*/#&/' /etc/ssh/sshd_config

    # Добавляем новые файлы конфигурации
   if [ "$ALLOW_ROOT_SSH" = true ]; then
        cat << EOF >> /etc/ssh/sshd_config

# Custom SSH configuration (cloud/root mode)
Port $SSH_PORT
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
Protocol 2
MaxAuthTries 3
EOF
    else
        cat << EOF >> /etc/ssh/sshd_config

# Custom SSH configuration (secure mode)
Port $SSH_PORT
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
Protocol 2
MaxAuthTries 3
EOF
    fi

    if sudo sshd -t; then
        echo "[INFO] SSH config OK. Restarting..."
        sudo systemctl restart ssh.service
    else
        echo "[ERROR] SSH config invalid, restoring backup..."
        sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
        sudo systemctl restart ssh.service
        exit 1
    fi
}

# Настраиваем iptables
setup_iptables

#Настраиваем fail2ban
setup_fail2ban

# Настраиваем ssh
setup_ssh


# Включаем и запускаем службы
# WIP
sudo systemctl enable --now auditd


echo ""
echo "Setup completed"
echo "A system reboot is recommended to apply all changes"

read -p "Reboot now? [Y/n]: " answer
if [[ "$answer" =~ ^[Yy]$ || -z "$answer" ]]; then
    echo "Rebooting..."
    sudo reboot now
else
    echo "Reboot canceled, please reboot manually later."
fi
