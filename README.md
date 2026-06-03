# Squared

Squared is an automated build pipeline for customized Ubuntu Desktop ISOs. Inspired by [Cubic](https://github.com/PJ-Singh-001/Cubic) but with one less dimension (no GUI, CLI-only tool). Uses a reproducible, scriptable Docker container to produce a bootable Ubuntu Desktop ISO-file. For more advanced use-cases it is recommended to use Cubic.

---

## Requirements

- Docker
- An Ubuntu desktop ISO (downloaded separately from [Ubuntu's official website](https://releases.ubuntu.com/))
- ~15 GB of free disk space for the working directory where the base ISO is extracted
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
UBUNTU_ISO=/path/to/ubuntu-desktop-amd64.iso
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
    -v /path/to/ubuntu-desktop-amd64.iso:/input/base.iso:ro \
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
| `TZ` | `UTC` | Timezone used for the datestamp in the output filename. Accepts any tz database name (e.g. `Europe/Stockholm`). |
| `UBUNTU_ISO` | NONE (User required) | Host path to the source Ubuntu ISO. Compose only - maps it to `/input/base.iso` inside the container. |
| `BASE_ISO` | `/input/base.iso` | Path to the source ISO **inside the container**. Only needed if you change the Compose volume mount. |
| `OUTPUT_DIR` | `/output` | Directory where the finished ISO is written **inside the container**. |
| `LABEL` | `CUSTOM_UBUNTU` | Volume label embedded in the ISO. Visible in file managers and `blkid`. |
| `SQUASHFS` | *(auto-detected)* | Squashfs filename to extract and repack from `casper/`. If unset, the build scans `casper/` and uses the file automatically when exactly one is found. Set explicitly when the ISO contains multiple squashfs files. |
| `OUTPUT_NAME` | `custom-ubuntu` | Base name of the output ISO file. A datestamp is always appended, producing `<OUTPUT_NAME>-YYYYMMDD-HHMM.iso`. |
| `INTERACTIVE` | `0` | Set to `1` to drop into an interactive shell inside the chroot after `install.sh` finishes. Exit the shell to resume the build. See [Interactive shell](#interactive-shell). |

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
| **RAM boot (quiet)** | Copies the entire filesystem into RAM before mounting - default. The boot media can be removed once the system is up. |
| **RAM boot (verbose)** | Same as above with full kernel output, useful for debugging boot issues. |
| **Run from media** | Mounts the squashfs directly from the USB/disc without copying to RAM. Slower but works on systems with less memory. |

The `toram` kernel parameter (used by the first two entries) requires enough free RAM to hold the decompressed filesystem, typically **6–8 GB** for this image.

---

## Customization

Edit [`overlay/install.sh`](overlay/install.sh) to change what gets installed or configured. The script runs as root inside the chroot. After it exits, [`scripts/chroot-cleanup.sh`](scripts/chroot-cleanup.sh) runs automatically to remove the apt cache, logs, machine-id, and SSH host keys before the image is compressed.

Place additional `.deb` packages or resource files in `overlay/resources/` - `install.sh` installs everything matching `./resources/*.deb` automatically.

### Interactive shell

Set `INTERACTIVE=1` to pause the build after `install.sh` and drop into a live bash shell inside the chroot. This lets you inspect the environment, run commands, and make one-off changes before the filesystem is repacked into the ISO.

**With Docker Compose:**

```bash
INTERACTIVE=1 docker compose run --rm iso-builder
```

**With Docker directly:**

```bash
docker run --rm -it --privileged \
    -e INTERACTIVE=1 \
    -v /path/to/ubuntu-desktop-amd64.iso:/input/base.iso:ro \
    -v $(pwd)/overlay:/build/overlay:ro \
    -v $(pwd)/work:/build/work \
    -v $(pwd)/output:/output \
    iso-builder
```

> **Note:** The `-it` flag (or `stdin_open`/`tty` in Compose) is required. Without a TTY, the interactive shell exits immediately.

Type `exit` or press `Ctrl-D` to leave the shell and continue the build normally.
