#!/usr/bin/env bash
# Runs inside the Docker container. Produces a bootable Ubuntu live ISO
# that loads its entire filesystem into RAM on boot (casper toram).
set -euo pipefail

# -- Paths ---------------------------------------------------------------------
BASE_ISO="${BASE_ISO:-/input/base.iso}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
WORK_ISO="/build/work/iso"
WORK_FS="/build/work/squashfs"
OVERLAY_DIR="/build/overlay"
SCRIPT_DIR="/build/scripts"
GRUB_CFG="/build/grub/grub.cfg"
LABEL="${LABEL:-CUSTOM_UBUNTU_2604}"
SQUASHFS="${SQUASHFS:-filesystem.squashfs}"
OUTPUT_NAME="${OUTPUT_NAME:-custom-ubuntu-26.04}"

# -- Preflight checks ----------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: must run as root (use --privileged with docker run)" >&2
    exit 1
fi

if [[ ! -f "$BASE_ISO" ]]; then
    echo "ERROR: base ISO not found at $BASE_ISO" >&2
    echo "       Mount it with: -v /path/to/ubuntu.iso:/input/base.iso:ro" >&2
    exit 1
fi

if [[ ! -f "$OVERLAY_DIR/install.sh" ]]; then
    echo "ERROR: install.sh not found in $OVERLAY_DIR" >&2
    echo "       Mount overlay with: -v \$(pwd)/overlay:/build/overlay:ro" >&2
    exit 1
fi

mkdir -p "$WORK_ISO" "$WORK_FS" "$OUTPUT_DIR"

# -- Step 1: Extract source ISO ------------------------------------------------
echo
echo "[1/6] Extracting base ISO..."
# Wipe any previous run's extracted ISO
rm -rf "${WORK_ISO:?}"/*
xorriso -osirrox on -indev "$BASE_ISO" -extract / "$WORK_ISO" 2>/dev/null
chmod -R u+w "$WORK_ISO"

# Capture the boot layout flags from the source ISO's system area (MBR, GPT,
# El Torito). xorriso reads these directly from the ISO's byte ranges, not
# from extracted files, so they work regardless of which boot files the ISO
# ships. We strip -V since we set our own label.
BOOT_FLAGS=$(xorriso -indev "$BASE_ISO" -report_system_area as_mkisofs 2>/dev/null \
    | grep -v '^\s*-V ' \
    | tr '\n' ' ')

echo "      Done."

# -- Step 2: Extract squashfs root filesystem ----------------------------------
echo
echo "[2/6] Extracting squashfs root filesystem..."
rm -rf "${WORK_FS:?}"/*
unsquashfs -d "$WORK_FS" "$WORK_ISO/casper/$SQUASHFS"
echo "      Done."

# -- Step 3: Prepare chroot ----------------------------------------------------
echo
echo "[3/6] Preparing chroot environment..."

# Resolve DNS inside chroot during package installs
cp /etc/resolv.conf "$WORK_FS/etc/resolv.conf"

mount --bind /dev      "$WORK_FS/dev"
mount --bind /dev/pts  "$WORK_FS/dev/pts"
mount -t proc  proc    "$WORK_FS/proc"
mount -t sysfs sysfs   "$WORK_FS/sys"
mount -t tmpfs tmpfs   "$WORK_FS/run"

# Always unmount cleanly, even on error
cleanup() {
    echo
    echo "[cleanup] Unmounting chroot filesystems..."
    umount -lf "$WORK_FS/dev/pts" 2>/dev/null || true
    umount -lf "$WORK_FS/dev"     2>/dev/null || true
    umount -lf "$WORK_FS/proc"    2>/dev/null || true
    umount -lf "$WORK_FS/sys"     2>/dev/null || true
    umount -lf "$WORK_FS/run"     2>/dev/null || true
}
trap cleanup EXIT

echo "      Done."

# -- Step 4: Copy overlay and run install.sh inside chroot ---------------------
echo
echo "[4/6] Running customizations inside chroot..."

cp -r "$OVERLAY_DIR" "$WORK_FS/tmp/overlay"
cp -r "$SCRIPT_DIR" "$WORK_FS/tmp/scripts"

chroot "$WORK_FS" /bin/bash -c "
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    export HOME=/root
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

    # Run the user's customization script
    cd /tmp/overlay
    bash install.sh

    # Run the post-install cleanup defined in this repo
    bash /tmp/scripts/chroot-cleanup.sh
"

echo "      Done."

# -- Step 5: Repack squashfs ---------------------------------------------------
echo
echo "[5/6] Repacking squashfs (this takes a few minutes)..."

rm -f "$WORK_ISO/casper/$SQUASHFS"

mksquashfs "$WORK_FS" "$WORK_ISO/casper/$SQUASHFS" \
    -comp zstd \
    -Xcompression-level 15 \
    -noappend \
    -wildcards \
    -e 'proc/*' \
    -e 'sys/*' \
    -e 'dev/*' \
    -e 'run/*'

# casper reads this to know how much RAM it needs before expanding the squashfs
printf "$(du -sx --block-size=1 "$WORK_FS" | cut -f1)" \
    > "$WORK_ISO/casper/${SQUASHFS%.squashfs}.size"

echo "      Done. Squashfs size: $(du -sh "$WORK_ISO/casper/$SQUASHFS" | cut -f1)"

# -- Step 6: Rebuild bootable ISO ---------------------------------------------
echo
echo "[6/6] Building final ISO..."

cp "$GRUB_CFG" "$WORK_ISO/boot/grub/grub.cfg"

TIMESTAMP=$(date +%Y%m%d-%H%M)
OUTPUT_ISO="$OUTPUT_DIR/${OUTPUT_NAME}-${TIMESTAMP}.iso"

# Use the boot flags captured from the source ISO in Step 1.
# eval is required because $BOOT_FLAGS contains single-quoted interval
# references (e.g. '--interval:local_fs:0s-15s::/input/base.iso') that
# xorriso emits and expects to receive back as shell-quoted tokens.
eval "xorriso -as mkisofs \
    -r \
    -V '$LABEL' \
    -o '$OUTPUT_ISO' \
    $BOOT_FLAGS \
    '$WORK_ISO'"

echo
echo "------------------------------------------------------------"
echo " ISO complete: $OUTPUT_ISO"
echo " Size:         $(du -sh "$OUTPUT_ISO" | cut -f1)"
echo "------------------------------------------------------------"
