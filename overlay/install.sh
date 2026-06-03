#!/usr/bin/env bash
# Runs inside the chroot as root. Customize this script to configure
# your live system. The working directory is the overlay folder itself,
# so ./resources/ is directly accessible.
set -euo pipefail

# -- Example: set hostname -------------------------------------------------
HOSTNAME=${HOSTNAME:-custom-ubuntu}
hostname $HOSTNAME

# -- Example: update repositories and packages -------------------------------------------------
echo
echo "Updating repositories and packages"
apt-get update
apt-get upgrade -y

# -- Example: install packages -------------------------------------------------
PACKAGES=${PACKAGES:-nano}
echo
echo "Installing APT packages: $PACKAGES"
apt-get update
apt-get install -y $PACKAGES

# -- Example: install local .deb packages from resources/ ---------------------
# apt-get install -y ./resources/*.deb

# -- Example: copy a config file ----------------------------------------------
# cp resources/myconfig /etc/myconfig

# -- Example: create a default user ----------------------------------------------
# These can be overridden via overlay/.env
USERNAME="${USERNAME:-user}"
PASSWORD="${PASSWORD:-changeme}"

# Create the user with a home directory and bash as default shell
useradd -m -s /bin/bash -c "Default User" "$USERNAME"

# Add to standard desktop groups
usermod -aG sudo,audio,video,plugdev,netdev "$USERNAME"

echo "${USERNAME}:${PASSWORD}" | chpasswd

# -- Example: run the rest of the setup as the new user ----------------------
# Use a heredoc with su to drop privileges for user-space configuration.
# Commands inside will execute as $USERNAME with their home directory and
# environment loaded (equivalent to an interactive login shell).
su - "$USERNAME" <<USEREOF
# Set up dotfiles, configure the shell, etc.
mkdir -p ~/bin
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
USEREOF

# Configure GDM3 auto-login (Ubuntu 22.04+ default display manager)
mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf <<EOF
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=${USERNAME}

[security]

[xdmcp]

[chooser]

[debug]
EOF

# If LightDM is used instead of GDM3, uncomment the block below:
# mkdir -p /etc/lightdm/lightdm.conf.d
# cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
# [Seat:*]
# autologin-user=${USERNAME}
# autologin-user-timeout=0
# EOF
