#!/usr/bin/env bash
# Install apt packages on a GitHub Ubuntu runner, falling back across mirrors.
# The runner's default (Azure) mirror and archive.ubuntu.com both have DNS
# outages from time to time, so try several and only proceed once every
# requested package has an install candidate.
#
# Usage: install-linux-deps.sh <package>...
set -uo pipefail

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <package>..." >&2
  exit 2
fi
PACKAGES=("$@")

. /etc/os-release
CODENAME="${VERSION_CODENAME:?cannot detect Ubuntu codename}"

APT_OPTS=(-o Acquire::Retries=3 -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20)

# Mirrors to try in order. "default" = the runner's stock configuration.
MIRRORS=(
  default
  http://azure.archive.ubuntu.com/ubuntu
  http://archive.ubuntu.com/ubuntu
  http://mirrors.edge.kernel.org/ubuntu
  http://mirror.math.princeton.edu/pub/ubuntu
)

BACKUP_DIR=/tmp/apt-sources-backup
DEB822=/etc/apt/sources.list.d/ubuntu.sources

sudo mkdir -p "$BACKUP_DIR"
[ -f /etc/apt/sources.list ] && sudo cp -n /etc/apt/sources.list "$BACKUP_DIR/sources.list"
[ -f "$DEB822" ] && sudo cp -n "$DEB822" "$BACKUP_DIR/ubuntu.sources"

use_mirror() {
  local mirror="$1"
  if [ "$mirror" = default ]; then
    [ -f "$BACKUP_DIR/sources.list" ] && sudo cp "$BACKUP_DIR/sources.list" /etc/apt/sources.list
    [ -f "$BACKUP_DIR/ubuntu.sources" ] && sudo cp "$BACKUP_DIR/ubuntu.sources" "$DEB822"
    return
  fi
  sudo rm -f "$DEB822"
  sudo tee /etc/apt/sources.list >/dev/null <<EOF
deb $mirror $CODENAME main restricted universe multiverse
deb $mirror $CODENAME-updates main restricted universe multiverse
deb $mirror $CODENAME-backports main restricted universe multiverse
deb $mirror $CODENAME-security main restricted universe multiverse
EOF
}

all_available() {
  local pkg
  for pkg in "${PACKAGES[@]}"; do
    if ! apt-cache policy "$pkg" 2>/dev/null | grep -q 'Candidate: [^(]'; then
      echo "  missing candidate: $pkg"
      return 1
    fi
  done
}

for mirror in "${MIRRORS[@]}"; do
  echo "::group::apt mirror: $mirror"
  use_mirror "$mirror"
  sudo apt-get "${APT_OPTS[@]}" update -y
  if all_available; then
    echo "::endgroup::"
    for attempt in 1 2 3; do
      if sudo apt-get "${APT_OPTS[@]}" install -y --no-install-recommends "${PACKAGES[@]}"; then
        echo "Installed packages using mirror: $mirror"
        exit 0
      fi
      echo "install attempt $attempt failed, retrying in 10s..."
      sleep 10
    done
  else
    echo "::endgroup::"
    echo "::warning::apt mirror $mirror unusable, trying next"
  fi
done

echo "::error::Could not install packages from any mirror: ${PACKAGES[*]}"
exit 1
