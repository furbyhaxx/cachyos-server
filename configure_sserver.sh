#!/bin/bash

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

    # Return the result by echoing it
    echo "$input"
}

sudo mv /etc/motd /etc/motd.original
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

echo "--> Assign public interface to the 'public' firewall zone"
first_if=$(ip -o -4 addr show | awk '$2 != "lo" {print $2}' | head -n 1)
echo "Available interfaces:"
ip -o -4 addr show | awk '$2 != "lo" {print $2, $4}'
PUBLIC_INTERFACE=$(ask_for "Enter public facing interface", $first_if)
