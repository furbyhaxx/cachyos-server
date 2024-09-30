#!/bin/bash

# run with: wget https://raw.githubusercontent.com/furbyhaxx/cachyos-server/refs/heads/main/configure_server.sh && chmod +x && ./configure_server.sh

# performs basic configuration of a public facing cachyos-server

# Log a message before each command runs
log_and_run() {
    echo "Executing: $1"
    eval $1
}

ask_for() {
    local message=$1
    local default_value=$2
    local input

    # Read user input with a prompt message and default value
    read -p "$message [$default_value]: " input

    # If input is empty, use the default value
    input=${input:-$default_value}

    echo "$input"
}

ask_yes_no() {
    local prompt="$1"
    local default_answer="$2"

    # Convert default answer to lowercase
    default_answer=$(echo "$default_answer" | tr '[:upper:]' '[:lower:]')

    # Prompt the user for input
    while true; do
        read -p "$prompt [y/n]: " answer

        # Convert input to lowercase
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

        # If no input was given, use the default answer (if provided)
        if [[ -z "$answer" && -n "$default_answer" ]]; then
            answer=$default_answer
        fi

        # Validate the input
        case "$answer" in
            y|yes)
                return 0  # Yes
                ;;
            n|no)
                return 1  # No
                ;;
            *)
                echo "Please answer y/n or yes/no."
                ;;
        esac
    done
}


sudo mv /etc/motd /etc/motd.original 2&>1 >> /dev/null
OLD_HOSTNAME=$(hostname)
OLD_TLD=$(hostname -d)
HOSTNAME=$(ask_for "Enter hostname without TLD", $OLD_HOSTNAME)
HOSTNAME_TLD=$(ask_for "Enter hostname TLD", $OLD_TLD)

sudo bash -c "cat << EOF > /etc/hostname
$HOSTNAME
EOF"
sudo sed -i "s/${OLD_HOSTNAME}.${OLD_TLD}/${HOSTNAME}.${HOSTNAME_TLD}/" /etc/hosts
sudo sed -i "s/${OLD_HOSTNAME}/${HOSTNAME}/" /etc/hosts


echo "--> Installing firewalld"
sudo pacman -S --noconfirm firewalld

echo "--> Changing SSH port"
SSH_PORT=$(ask_for "Enter new SSH port", 8022)
sudo sed -i "s/^#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config

echo "--> Allowing ssh port ${SSH_PORT} from the public zone"
sudo firewall-cmd --permanent --zone=public --add-port=${SSH_PORT}/tcp

echo "--> Assign public interface to the 'public' firewall zone"
first_if=$(ip -o -4 addr show | awk '$2 != "lo" {print $2}' | head -n 1)
echo "Available interfaces:"
ip -o -4 addr show | awk '$2 != "lo" {print $2, $4}'
PUBLIC_INTERFACE=$(ask_for "Enter public facing interface", $first_if)

echo "--> Adding ${PUBLIC_INTERFACE} to the public zone"
sudo firewall-cmd --permanent --zone=public --change-interface=eth0

echo "--> Installing fail2ban"
sudo pacman -S --noconfirm fail2ban
sudo touch /var/log/fail2ban.log

echo "--> Configuring fail2ban"
sudo bash -c "cat << EOF >> /etc/fail2ban/jail.local

[sshd]
enabled = true
port = ${SSH_PORT}
filter = sshd
logpath = /var/log/auth.log
maxretry = 4
bantime = 300    # 5 minutes
findtime = 600   # 10 minutes window

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = iptables-multiport
bantime = 43200 
findtime = 86400
maxretry = 3 

EOF"


echo "Do you want to add another superuser?"
if ask_yes_no "Do you want to continue?" "yes"; then
    USERNAME=$(ask_for "Enter the superusers name", "admin")
    sudo useradd -m ${USERNAME}
    sudo usermod -aG wheel ${USERNAME}
    sudo passwd ${USERNAME}
fi

echo "--> Enabling fail2ban"
sudo systemctl enable --now fail2ban

echo "--> Enabling firewalld"
sudo systemctl enable --now firewalld
