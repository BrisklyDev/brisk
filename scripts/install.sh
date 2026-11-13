#!/usr/bin/env bash
# ==============================================================================
# Brisk Download Manager - Linux One-Liner Installer & Uninstaller
# https://github.com/BrisklyDev/brisk
# ==============================================================================

set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info() {
  printf "${BLUE}[INFO]${NC} %b\n" "$*"
}

success() {
  printf "${GREEN}[OK]${NC} %b\n" "$*"
}

warn() {
  printf "${YELLOW}[WARN]${NC} %b\n" "$*"
}

error() {
  printf "${RED}[ERROR]${NC} %b\n" "$*" >&2
}

# Configuration
REPO="${BRISK_REPO:-BrisklyDev/brisk}"
FALLBACK_VERSION="v2.5.0"
VERSION="${BRISK_VERSION:-}"
TMP_DIR=""

cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

# Determine installation scope
if [ "$(id -u)" -eq 0 ]; then
  INSTALL_DIR="${BRISK_DIR:-/opt/brisk}"
  BIN_DIR="${BRISK_BIN_DIR:-/usr/local/bin}"
  DESKTOP_DIR="/usr/share/applications"
  ICON_DIR="/usr/share/icons/hicolor"
else
  INSTALL_DIR="${BRISK_DIR:-$HOME/.local/share/brisk}"
  BIN_DIR="${BRISK_BIN_DIR:-$HOME/.local/bin}"
  DESKTOP_DIR="$HOME/.local/share/applications"
  ICON_DIR="$HOME/.local/share/icons/hicolor"
fi

# ------------------------------------------------------------------------------
# Uninstall Routine
# ------------------------------------------------------------------------------
uninstall_brisk() {
  info "Uninstalling Brisk Download Manager..."

  if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    success "Removed application directory: $INSTALL_DIR"
  fi

  if [ -L "$BIN_DIR/brisk" ] || [ -f "$BIN_DIR/brisk" ]; then
    rm -f "$BIN_DIR/brisk"
    success "Removed binary symlink: $BIN_DIR/brisk"
  fi

  if [ -f "$DESKTOP_DIR/brisk.desktop" ]; then
    rm -f "$DESKTOP_DIR/brisk.desktop"
    success "Removed desktop entry: $DESKTOP_DIR/brisk.desktop"
  fi

  # Remove icons
  find "$ICON_DIR" -name "brisk.*" -delete 2>/dev/null || true

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
  fi

  success "Brisk has been completely uninstalled."
  exit 0
}

# Handle --uninstall flag or UNINSTALL=1
if [ "${1:-}" = "--uninstall" ] || [ "${1:-}" = "-u" ] || [ "${UNINSTALL:-0}" = "1" ]; then
  uninstall_brisk
fi

# ------------------------------------------------------------------------------
# System & Architecture Verification
# ------------------------------------------------------------------------------
check_system() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"

  if [ "$OS" != "linux" ]; then
    error "This installer is designed for Linux. Detected OS: $OS"
    if [ "$OS" = "darwin" ]; then
      info "For macOS, please download the DMG from: https://github.com/$REPO/releases/latest"
    fi
    exit 1
  fi

  if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "amd64" ]; then
    error "Brisk pre-compiled binary tarball currently supports x86_64 / amd64 architecture. Detected: $ARCH"
    info "For ARM (aarch64), consider installing via Flatpak: flatpak install flathub io.github.BrisklyDev.Brisk"
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# Check Dependencies & Prerequisites
# ------------------------------------------------------------------------------
check_prerequisites() {
  local missing_tools=()
  for tool in curl tar xz; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing_tools+=("$tool")
    fi
  done

  if [ ${#missing_tools[@]} -gt 0 ]; then
    error "Missing required utilities: ${missing_tools[*]}"
    info "Please install them using your package manager (e.g. sudo apt install ${missing_tools[*]})"
    exit 1
  fi

  # Check Linux runtime libraries (keybinder-3 and appindicator)
  local missing_pkgs=""
  local has_keybinder=0
  local has_appindicator=0

  if ldconfig -p 2>/dev/null | grep -q 'libkeybinder-3\.0'; then
    has_keybinder=1
  elif [ -f /usr/lib/libkeybinder-3.0.so.0 ] || [ -f /usr/lib64/libkeybinder-3.0.so.0 ] || [ -f /usr/lib/x86_64-linux-gnu/libkeybinder-3.0.so.0 ]; then
    has_keybinder=1
  fi

  if ldconfig -p 2>/dev/null | grep -q -E 'libayatana-appindicator3|libappindicator3'; then
    has_appindicator=1
  elif [ -f /usr/lib/libayatana-appindicator3.so.1 ] || [ -f /usr/lib64/libayatana-appindicator3.so.1 ] || [ -f /usr/lib/x86_64-linux-gnu/libayatana-appindicator3.so.1 ] || [ -f /usr/lib/libappindicator3.so.1 ] || [ -f /usr/lib64/libappindicator3.so.1 ] || [ -f /usr/lib/x86_64-linux-gnu/libappindicator3.so.1 ]; then
    has_appindicator=1
  fi

  if [ "$has_keybinder" -eq 0 ] || [ "$has_appindicator" -eq 0 ]; then
    warn "One or more recommended desktop libraries might be missing:"
    [ "$has_keybinder" -eq 0 ] && warn "  - libkeybinder-3.0 (required for global shortcuts)"
    [ "$has_appindicator" -eq 0 ] && warn "  - libayatana-appindicator3 / libappindicator3 (required for system tray)"
    warn "If Brisk fails to start, install them via your distribution package manager:"
    if [ -f /etc/debian_version ]; then
      warn "  sudo apt-get install -y libkeybinder-3.0-0 libayatana-appindicator3-1"
    elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
      warn "  sudo dnf install -y keybinder3 libayatana-appindicator-gtk3"
    elif [ -f /etc/arch-release ]; then
      warn "  sudo pacman -S --needed libkeybinder3 libappindicator-gtk3"
    fi
  fi
}

# ------------------------------------------------------------------------------
# Resolve Release Version
# ------------------------------------------------------------------------------
resolve_version() {
  if [ -z "$VERSION" ]; then
    info "Fetching latest release information from GitHub..."
    local latest_tag
    latest_tag=$(curl -sSL -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
      | grep '"tag_name":' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/') || true

    if [ -n "$latest_tag" ]; then
      VERSION="$latest_tag"
    else
      warn "Unable to fetch latest tag via GitHub API (possibly rate-limited). Using fallback: $FALLBACK_VERSION"
      VERSION="$FALLBACK_VERSION"
    fi
  fi
  info "Installing Brisk version: ${BOLD}$VERSION${NC}"
}

# ------------------------------------------------------------------------------
# Download & Extract
# ------------------------------------------------------------------------------
install_brisk() {
  local clean_version="${VERSION#v}"
  local filename="Brisk-v${clean_version}-linux-x86_64.tar.xz"
  local download_url="https://github.com/$REPO/releases/download/$VERSION/$filename"

  TMP_DIR=$(mktemp -d)

  info "Downloading from: $download_url"
  if ! curl -fSL --progress-bar "$download_url" -o "$TMP_DIR/$filename"; then
    error "Download failed. Please check your internet connection or the release tag '$VERSION'."
    exit 1
  fi

  info "Extracting bundle to $INSTALL_DIR..."
  mkdir -p "$INSTALL_DIR"
  rm -rf "${INSTALL_DIR:?}"/*

  tar -xJf "$TMP_DIR/$filename" -C "$INSTALL_DIR"

  # Ensure binary permissions
  if [ -f "$INSTALL_DIR/brisk" ]; then
    chmod +x "$INSTALL_DIR/brisk"
  else
    error "Executable 'brisk' not found in extracted archive!"
    exit 1
  fi

  if [ -f "$INSTALL_DIR/updater/brisk_auto_updater" ]; then
    chmod +x "$INSTALL_DIR/updater/brisk_auto_updater"
  fi

  # Create symlink in bin directory
  mkdir -p "$BIN_DIR"
  ln -sf "$INSTALL_DIR/brisk" "$BIN_DIR/brisk"
  success "Linked binary: $BIN_DIR/brisk -> $INSTALL_DIR/brisk"

  # Desktop Entry & Icons
  mkdir -p "$DESKTOP_DIR"
  mkdir -p "$ICON_DIR/256x256/apps"
  mkdir -p "$ICON_DIR/scalable/apps"

  local icon_src_256="$INSTALL_DIR/data/flutter_assets/assets/icons/logo-new-256.png"
  local icon_src_svg="$INSTALL_DIR/data/flutter_assets/assets/icons/logo-new.svg"

  if [ -f "$icon_src_256" ]; then
    cp "$icon_src_256" "$ICON_DIR/256x256/apps/brisk.png"
  fi
  if [ -f "$icon_src_svg" ]; then
    cp "$icon_src_svg" "$ICON_DIR/scalable/apps/brisk.svg"
  fi

  # Create .desktop file with absolute Exec and standard Icon name
  cat <<EOF > "$DESKTOP_DIR/brisk.desktop"
[Desktop Entry]
Name=Brisk
Comment=Ultra-fast, modern download manager for desktop
Exec=$BIN_DIR/brisk %U
Icon=brisk
Terminal=false
Type=Application
Categories=Network;Utility;FileTransfer;
MimeType=x-scheme-handler/brisk;
StartupNotify=true
StartupWMClass=io.github.BrisklyDev.Brisk
EOF
  chmod 644 "$DESKTOP_DIR/brisk.desktop"
  success "Created desktop launcher: $DESKTOP_DIR/brisk.desktop"

  # Update caches if available
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
  fi
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f "$ICON_DIR" 2>/dev/null || true
  fi

  echo ""
  printf "${GREEN}${BOLD}====================================================${NC}\n"
  printf "${GREEN}${BOLD}  Brisk Download Manager installed successfully!     ${NC}\n"
  printf "${GREEN}${BOLD}====================================================${NC}\n"
  echo ""
  info "Installed version: $VERSION"
  info "Install location:  $INSTALL_DIR"
  info "Executable:        $BIN_DIR/brisk"
  echo ""

  # Check PATH
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
      warn "$BIN_DIR is not in your PATH."
      warn "Add it by adding this line to your ~/.bashrc or ~/.zshrc:"
      warn "  export PATH=\"\$PATH:$BIN_DIR\""
      echo ""
      ;;
  esac

  info "You can launch Brisk from your application menu or run: brisk"
  info "To uninstall in the future, run:"
  info "  curl -fsSL https://raw.githubusercontent.com/$REPO/main/scripts/install.sh | bash -s -- --uninstall"
}

main() {
  check_system
  check_prerequisites
  resolve_version
  install_brisk
}

main "$@"
