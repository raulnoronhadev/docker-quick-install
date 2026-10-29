# install-docker.sh

Idempotent Docker CE installer for Linux machines.

Written to set up the computers in a school lab, where the same machine may be
reimaged or re-provisioned often — running the script again is always safe.

## What it does

1. Removes the Docker packages shipped by the distribution (`docker.io`, `podman-docker`, old `containerd`/`runc`, …).
2. Adds Docker's official GPG key and APT repository.
3. Installs Docker Engine, CLI, containerd, buildx and compose.
4. Enables and starts `docker.service` at boot.
5. Adds the chosen users to the `docker` group.
6. Verifies the install by running the `hello-world` container.

On Zorin OS, `VERSION_CODENAME` is not a valid Ubuntu codename, so the script
reads `UBUNTU_CODENAME` from `/etc/os-release` to pick the right repository.

## Requirements

- A Debian/Ubuntu-based system (Zorin OS, Ubuntu, Linux Mint, …)
- root access via `sudo`
- Internet access to `download.docker.com`

## Usage

```bash
chmod +x install-docker.sh

# adds the user who invoked sudo to the docker group
sudo ./install-docker.sh

# also adds these users to the docker group
sudo ./install-docker.sh student teacher
```

## After installing

Users added to the `docker` group have to log out and back in (or reboot)
before they can use `docker` without `sudo`. To test in the current shell:

```bash
newgrp docker && docker ps
```

A full log of each run is written to `/var/log/install-docker-YYYYmmdd-HHMMSS.log`.
