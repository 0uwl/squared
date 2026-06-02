#!/usr/bin/env bash
# Runs inside the chroot as root. Customize this script to configure
# your live system. The working directory is the overlay folder itself,
# so ./resources/ is directly accessible.
set -euo pipefail

# ── Example: install packages ─────────────────────────────────────────────────
# apt-get update
# apt-get install -y --no-install-recommends \
#     vim \
#     htop \
#     tmux

# ── Example: install local .deb packages from resources/ ─────────────────────
# apt-get install -y ./resources/*.deb

# ── Example: create a user ────────────────────────────────────────────────────
# useradd -m -s /bin/bash myuser
# echo "myuser:password" | chpasswd

# ── Example: copy a config file ──────────────────────────────────────────────
# cp resources/myconfig /etc/myconfig
