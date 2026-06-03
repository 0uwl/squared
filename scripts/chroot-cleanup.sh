#!/usr/bin/env bash
# Runs at the end of the chroot phase to shrink the image and avoid
# carrying stale state into the live environment.
set -euo pipefail

# Remove the overlay directory used during this build
rm -rf /tmp/overlay

# Wipe apt cache - it would be stale the moment the ISO boots anyway
apt-get clean
rm -rf /var/lib/apt/lists/*

# Wipe temporary files
rm -rf /tmp/* /var/tmp/*

# Wipe logs - they reflect the build environment, not the live system
find /var/log -type f -delete

# A unique machine-id is generated on first boot by systemd.
# Shipping a pre-baked one causes all live boots to share an identity,
# which breaks D-Bus, systemd-resolved, and network fingerprinting.
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

# Remove the SSH host keys baked in from the base ISO; new ones are
# generated on first boot by openssh-server if it is installed.
rm -f /etc/ssh/ssh_host_*

# Clear bash history that may have been written during install.sh
rm -f /root/.bash_history
history -c 2>/dev/null || true
