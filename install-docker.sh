#!/usr/bin/env bash
#
# install-docker.sh — Installs Docker CE on the lab computers (Zorin OS / Ubuntu base)
#
# Usage:
#   sudo ./install-docker.sh                      # adds the user who invoked sudo to the docker group
#   sudo ./install-docker.sh student teacher      # also adds these users to the docker group
#
# The script is idempotent: it can be run again on the same machine without breaking anything.

set -euo pipefail

LOG="/var/log/install-docker-$(date +%Y%m%d-%H%M%S).log"
KEYRING="/etc/apt/keyrings/docker.asc"
REPO_FILE="/etc/apt/sources.list.d/docker.list"

log()  { echo -e "\n\033[1;34m==>\033[0m $*"; }
ok()   { echo -e "\033[1;32m  ✓\033[0m $*"; }
warn() { echo -e "\033[1;33m  !\033[0m $*"; }
die()  { echo -e "\033[1;31m  ✗\033[0m $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run it with sudo: sudo $0"

command -v apt-get >/dev/null || die "This script is meant for Debian/Ubuntu-based systems."

# Users to be added to the docker group: the ones passed as arguments + whoever invoked sudo
DOCKER_USERS=("$@")
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  DOCKER_USERS+=("$SUDO_USER")
fi

# Codename of the Ubuntu base. On Zorin, VERSION_CODENAME may not be a valid
# Ubuntu codename, which is why UBUNTU_CODENAME takes precedence.
# shellcheck disable=SC1091
. /etc/os-release
CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
ARCH="$(dpkg --print-architecture)"

log "Detected system: ${PRETTY_NAME:-unknown}"
echo "    Ubuntu base  : $CODENAME"
echo "    architecture : $ARCH"
echo "    log          : $LOG"

case "$CODENAME" in
  focal|jammy|noble|oracular|plucky) ok "Codename supported by the official Docker repository." ;;
  *) warn "Codename '$CODENAME' not recognized — if apt fails, check whether Docker publishes packages for it." ;;
esac

exec > >(tee -a "$LOG") 2>&1

log "Removing old Docker packages shipped by the distribution"
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    apt-get remove -y "$pkg"
    ok "removed: $pkg"
  fi
done
ok "No conflicting packages left."

log "Installing dependencies"
apt-get update
apt-get install -y ca-certificates curl gnupg

log "Setting up Docker's GPG key"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$KEYRING.tmp"
# Only replace the existing key if the download completed
[ -s "$KEYRING.tmp" ] || die "Failed to download Docker's GPG key (no internet or a proxy blocking it?)."
mv "$KEYRING.tmp" "$KEYRING"
chmod a+r "$KEYRING"
ok "key stored at $KEYRING"

log "Registering the Docker repository"
echo "deb [arch=${ARCH} signed-by=${KEYRING}] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  > "$REPO_FILE"
cat "$REPO_FILE"
apt-get update

log "Installing Docker Engine, CLI, containerd, buildx and compose"
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log "Enabling and starting the service"
systemctl enable --now docker
systemctl is-active --quiet docker || die "The docker service did not start. Check: journalctl -xeu docker"
ok "docker.service active and enabled at boot"

if [ ${#DOCKER_USERS[@]} -gt 0 ]; then
  log "Adding users to the docker group"
  for u in "${DOCKER_USERS[@]}"; do
    if id "$u" >/dev/null 2>&1; then
      usermod -aG docker "$u"
      ok "$u added to the docker group"
    else
      warn "user '$u' does not exist on this machine — skipped"
    fi
  done
else
  warn "No users added to the docker group (running as root directly?)."
  warn "Run it later: sudo usermod -aG docker USERNAME"
fi

log "Verifying the installation"
docker version --format 'Client {{.Client.Version}} / Server {{.Server.Version}}'
docker run --rm hello-world >/dev/null 2>&1 \
  && ok "test container ran successfully" \
  || warn "could not run hello-world (no internet to pull the image?)"

log "Installation complete."
echo
echo "  Users added to the docker group need to LOG OUT AND BACK IN"
echo "  (or reboot the machine) to use docker without sudo."
echo "  To test right away, without logging out:  newgrp docker  &&  docker ps"
echo
echo "  Full log: $LOG"
