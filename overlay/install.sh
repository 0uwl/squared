#!/usr/bin/env bash
# Runs inside the chroot as root. Customize this script to configure
# your live system. The working directory is the overlay folder itself,
# so ./resources/ is directly accessible.
set -euo pipefail

# -- Example: install packages -------------------------------------------------
# apt-get update
# apt-get install -y --no-install-recommends \
#     vim \
#     htop \
#     tmux

# -- Example: install local .deb packages from resources/ ---------------------
# apt-get install -y ./resources/*.deb

# -- Example: copy a config file ----------------------------------------------
# cp resources/myconfig /etc/myconfig


# -- Example: create a default user ----------------------------------------------
USERNAME="user"

# Create the user with a home directory and bash as default shell
useradd -m -s /bin/bash -c "Default User" "$USERNAME"

# Add to standard desktop groups
usermod -aG sudo,audio,video,plugdev,netdev "$USERNAME"

# Set the password to "changeme"
echo "${USERNAME}:changeme" | chpasswd

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
