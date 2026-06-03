# Squared

Squared is an automated build pipeline for customized Ubuntu Desktop ISOs. Inspired by [Cubic](https://github.com/PJ-Singh-001/Cubic) but with one less dimension (no GUI, CLI-only tool). Uses a reproducible, scriptable Docker container to produce a bootable Ubuntu Desktop ISO-file. For more advanced use-cases it is still recommended to use Cubic.

Squared should be seen as a springboard for you to create your own custom Ubuntu Desktop ISO building pipeline. It covers the basics, but you are expected to do most of the actual customization.

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

## Customization

Edit [`overlay/install.sh`](overlay/install.sh) to change what gets installed or configured inside the build container. The script runs as root inside the chroot. After it exits, [`scripts/chroot-cleanup.sh`](scripts/chroot-cleanup.sh) runs automatically to remove the apt cache, logs, machine-id, and SSH host keys before the image is compressed.

The possibilites are endless which means that Squared cannot cover all possible scenarios for what you do inside the install.sh script. Squared should be seen as a springboard for you to create your own build pipeline for custom Ubuntu Desktop ISOs.

### Interactive shell

_THIS FEATURE IS CURRENTLY NON-FUNCTIONAL_

Set `INTERACTIVE=1` to pause the build after `install.sh` and drop into a live bash shell inside the chroot. This lets you inspect the environment, run commands, and make one-off changes before the filesystem is repacked into the ISO.

Issue the command `exit` or press `Ctrl-D` to exit the shell and continue the build process normally.

---

## Usage

### Installing
Clone this repository locally so that you get the example files and the correct project structure:
```bash
git clone https://github.com/0uwl/squared.git
```
__Using pre-built container__

There is a pre-built container image available. 
```bash
docker pull docker pull ghcr.io/0uwl/squared:latest
```

__Building container from source__

Move into the cloned repo and build the Squared container image locally:
```bash
docker build -t squared:latest    # This assumes you are currently standing inside the repo
```

### Running

__Docker Compose__

A compose.yml is included in the repo but you must change the volume that binds the base Ubuntu Desktop ISO file in to the build container. 

It is recommended to use `docker compose run` instead of the usual `docker compose up` since this command has the `--rm` flag which automatically removes the container after exiting.
```bash
docker compose run --rm squared
```

__Docker run__

If you prefer to run the container directly, you can do so with the following command (assuming the image is called `squared`):

```bash
docker run --rm --privileged \
    -v /path/to/ubuntu-desktop-amd64.iso:/input/base.iso:ro \
    -v $(pwd)/overlay:/build/overlay:ro \
    -v $(pwd)/work:/build/work \
    -v $(pwd)/output:/output \
    squared
```
Remember to update the base ISO volume.

### Output
The finished ISO is written to `./output/` with a datestamp in the filename by default. If you used the environment variable `OUTPUT_NAME`, the datestamp will still be added. 

If you plan to use the environment variable `OUTPUT_DIR` it is important to remember that you must also make a volume for the corresponding host directory where `OUTPUT_DIR` will be mounted, otherwise the output ISO will be stuck inside the container and removed with it.
