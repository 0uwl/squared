# Console Laptop ISO Builder

Automated build pipeline for a customized Ubuntu 26.04 LTS live ISO that runs entirely from RAM. Replaces the previous manual [Cubic](https://github.com/PJ-Singh-001/Cubic)-based workflow with a reproducible, scriptable Docker container.

---

## Requirements

- Docker
- A Ubuntu 26.04 LTS desktop ISO (downloaded separately)
- ~15 GB of free disk space for the working directory
- The Docker container must run with `--privileged` (required for chroot bind mounts)

---

## Project Structure

```
.
├── Dockerfile                     # Build environment with all tools
├── compose.yml                    # Docker Compose entry point
├── build.sh                       # 6-step pipeline (runs inside container)
├── grub/
│   └── grub.cfg                   # Bootloader config with toram entries
├── overlay/                       # Copied into the chroot at build time
│   ├── install.sh                 # OS customization script (edit this)
│   └── resources/                 # Binaries, .deb packages, config files
└── scripts/
    └── chroot-cleanup.sh          # Post-install cleanup (auto-run after install.sh)
```

---

## Building

### With Docker Compose (recommended)

**1.** Create a `.env` file at the project root to set the path to your source ISO:

```ini
UBUNTU_ISO=/path/to/ubuntu-26.04-desktop-amd64.iso
```

**2.** Build and run:

```bash
docker compose up --build
```

### With Docker directly

**1. Build the image:**

```bash
docker build -t iso-builder .
```

**2. Run the pipeline:**

```bash
docker run --rm --privileged \
    -v /path/to/ubuntu-26.04-desktop-amd64.iso:/input/base.iso:ro \
    -v $(pwd)/overlay:/build/overlay:ro \
    -v $(pwd)/work:/build/work \
    -v $(pwd)/output:/output \
    iso-builder
```

The finished ISO is written to `./output/` with a datestamp in the filename.

---

## Environment Variables

Set these in `.env` when using Compose, or pass with `-e KEY=VALUE` when using `docker run`.

| Variable | Default | Description |
|---|---|---|
| `UBUNTU_ISO` | `./ubuntu-26.04-desktop-amd64.iso` | Host path to the source Ubuntu ISO. Compose only — maps it to `/input/base.iso` inside the container. |
| `BASE_ISO` | `/input/base.iso` | Path to the source ISO **inside the container**. Only needed if you change the Compose volume mount. |
| `OUTPUT_DIR` | `/output` | Directory where the finished ISO is written **inside the container**. |
| `LABEL` | `CUSTOM_UBUNTU_2604` | Volume label embedded in the ISO. Visible in file managers and `blkid`. |
| `SQUASHFS` | `filesystem.squashfs` | Filename of the squashfs to extract and repack inside `casper/`. Override when the source ISO uses a different name (e.g. `ubuntu-server-minimal.squashfs`). |
| `OUTPUT_NAME` | `custom-ubuntu-26.04` | Base name of the output ISO file. A datestamp is always appended, producing `<OUTPUT_NAME>-YYYYMMDD-HHMM.iso`. |

---

## Build Pipeline
This is what the build.sh script does:

| Step | Description |
|---|---|
| **1** | Extract the source Ubuntu ISO into `work/iso/` |
| **2** | Extract `casper/filesystem.squashfs` into `work/squashfs/` |
| **3** | Bind-mount `/dev`, `/proc`, `/sys`, `/run` into the squashfs root for chroot |
| **4** | Copy `overlay/` into the chroot and run `install.sh`, then `chroot-cleanup.sh` |
| **5** | Repack the modified root filesystem back into `filesystem.squashfs` (zstd compression) |
| **6** | Assemble a hybrid BIOS+EFI bootable ISO with `xorriso` |

---

## Boot Menu

The ISO boots with GRUB and presents three entries:

| Entry | Description |
|---|---|
| **RAM boot (quiet)** | Copies the entire filesystem into RAM before mounting — default. The boot media can be removed once the system is up. |
| **RAM boot (verbose)** | Same as above with full kernel output, useful for debugging boot issues. |
| **Run from media** | Mounts the squashfs directly from the USB/disc without copying to RAM. Slower but works on systems with less memory. |

The `toram` kernel parameter (used by the first two entries) requires enough free RAM to hold the decompressed filesystem, typically **6–8 GB** for this image.

---

## Customization

Edit [`overlay/install.sh`](overlay/install.sh) to change what gets installed or configured. The script runs as root inside the chroot. After it exits, [`scripts/chroot-cleanup.sh`](scripts/chroot-cleanup.sh) runs automatically to remove the apt cache, logs, machine-id, and SSH host keys before the image is compressed.

Place additional `.deb` packages or resource files in `overlay/resources/` — `install.sh` installs everything matching `./resources/*.deb` automatically.
