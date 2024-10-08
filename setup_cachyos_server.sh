#!/bin/bash

# run with: wget https://raw.githubusercontent.com/furbyhaxx/cachyos-server/refs/heads/main/setup_cachyos_server.sh && chmod +x ./setup_cachyos_server.sh && ./setup_cachyos_server.sh

is_container() {
     grep -sq 'docker\|lxc\|pod\|kube' /proc/1/environ;
}

# enable cachyos repositories
echo "--> Configuring CachyOS repositories"
curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz && cd cachyos-repo
yes | sudo ./cachyos-repo.sh

# rate mirrors to speed up further pacman calls
echo "--> Rating mirrors"
sudo pacman -S --noconfirm paru cachyos-rate-mirrors
yes | cachyos-rate-mirrors

# modify pacman.conf
echo "--> Modifying pacman.conf"
# enable coloring of output
sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
# increase maximum parallel downloads
sudo sed -i 's/^ParallelDownloads = 5/ParallelDownloads = 15/' /etc/pacman.conf

# update system
echo "--> Performing system upgrade"
yes | paru --noconfirm

# modify os-release file
echo "--> Modifying os-release file"
sudo bash -c 'cat << EOF > /etc/os-release
NAME="CachyOS Linux"
PRETTY_NAME="CachyOS Server"
ID=cachyos
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://cachyos.org/"
DOCUMENTATION_URL="https://wiki.cachyos.org/"
SUPPORT_URL="https://forum.cachyos.org/"
BUG_REPORT_URL="https://github.com/cachyos"
PRIVACY_POLICY_URL="https://terms.archlinux.org/docs/privacy-policy/"
LOGO=cachyos
EOF'

# modify lsb-release file
echo "--> Modifying lsb-release file"
sudo bash -c 'cat << EOF > /etc/lsb-release
DISTRIB_ID=cachyos
DISTRIB_RELEASE="rolling"
DISTRIB_DESCRIPTION="CachyOS Server"
EOF'


# install packages
echo "--> Installing packages"
yes | sudo pacman -S --noconfirm tree which nano paru micro fastfetch sudo wget curl fail2ban git less fish firewalld netcat \
     cachyos-keyring cachyos-hooks cachyos-mirrorlist achyos-settings cachyos-v3-mirrorlist cachyos-v4-mirrorlist \
      

if ! $(is_container); then
     # not running in a container
     # installing bare metal packages
     yes | sudo pacman -S --noconfirm snapper chwd libselinux libsepol cachyos-snapper-support linux-cachyos-server-lto linux-cachyos-server-lto-headers
fi

echo "--> Allow 'wheel' group to sudo"
sudo chmod 0770 /etc/sudoers
sudo sed -i 's/^# \(%wheel ALL=(ALL:ALL) ALL\)/\1/' /etc/sudoers
sudo chmod 0440 /etc/sudoers

echo "--> Enabling nano syntax highlighting"
# Uncomment the line that includes /usr/share/nano/*.nanorc
sudo sed -i 's|^# include /usr/share/nano/\*.nanorc|include /usr/share/nano/*.nanorc|' /etc/nanorc
# Add the line include /usr/share/nano/extra/*.nanorc after the uncommented line if it doesn't already exist
sudo grep -qxF 'include /usr/share/nano/extra/*.nanorc' /etc/nanorc || echo 'include /usr/share/nano/extra/*.nanorc' | sudo tee -a /etc/nanorc > /dev/null

echo "--> Enabling command output coloring"
sudo bash -c "cat << EOF >> /etc/bash.bashrc
# Enable color support for various commands
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval \"\$(dircolors -b ~/.dircolors)\" || eval \"\$(dircolors -b)\"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    alias ip='ip --color=auto'
    alias diff='diff --color=auto'
    alias dmesg='dmesg --color=always'
fi
EOF"


echo "--> Set fish as default shell for root"
sudo chmod 0770 /etc/passwd
sudo sed -i.bak 's|^\(root:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*\):/bin/bash|\1:/bin/fish|' /etc/passwd
sudo chmod 0644 /etc/passwd

if ! $(is_container); then
     # not running in a container
     echo "--> Fix pacman hooks"
     sudo mkdir -p /etc/pacman.d/hooks/
     sudo bash -c "cat << EOF > /etc/pacman.d/hooks/99-grub-install.hook
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = linux
Target = linux-zen
Target = linux-lts
Target = linux-hardened
Target = cachyos-linux*

[Action]
Description = Updating GRUB after kernel installation...
When = PostTransaction
Exec = /bin/sh -c 'grub-mkconfig -o /boot/grub/grub.cfg'

EOF"
fi



echo "--> DONE"
