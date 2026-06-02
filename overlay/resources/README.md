# resources/

Place any files here that `install.sh` needs at build time: `.deb` packages,
tarballs, config files, scripts, etc.

This directory is copied into the chroot alongside `install.sh`, so everything
here is accessible as `./resources/<file>` from within that script.

> **Note:** Binary files (`.deb`, `.tar`, `.tar.gz`, `.iso`) are excluded from
> version control via `.gitignore`. Add them manually after cloning.
