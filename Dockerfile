FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    # ISO extraction and creation
    xorriso \
    # Squashfs tools (mksquashfs, unsquashfs)
    squashfs-tools \
    # GRUB modules for hybrid BIOS + EFI bootable ISOs
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-amd64-signed \
    shim-signed \
    # FAT filesystem support (required for EFI partition creation)
    dosfstools \
    mtools \
    # General utilities
    bash \
    coreutils \
    rsync \
    curl \
    wget \
    file \
    pv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY build.sh       /build/build.sh
COPY scripts/       /build/scripts/
COPY grub/          /build/grub/

RUN chmod +x /build/build.sh /build/scripts/*.sh

# Expected volume mounts at runtime:
#   /input/base.iso        — source Ubuntu ISO (read-only)
#   /build/overlay         — your customization folder with install.sh
#   /build/work            — working directory (needs ~10 GB free)
#   /output                — final ISO is written here

ENTRYPOINT ["/build/build.sh"]
