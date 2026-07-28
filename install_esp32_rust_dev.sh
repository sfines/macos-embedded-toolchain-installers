#!/bin/zsh
#
# install_esp32_rust_dev.sh
# Install the Rust toolchain for ESP32-WROOM development on macOS.
#
# Targets the common std/Wi-Fi path via esp-rs and the ESP-IDF framework.
#
# Usage:
#   ./install_esp32_rust_dev.sh [-t <target>] [-e <esp-idf-version>]
#
# Examples:
#   ./install_esp32_rust_dev.sh
#   ./install_esp32_rust_dev.sh -t esp32 -e v5.2.2
#

set -e

TARGET="esp32"          # ESP32-WROOM = Xtensa ESP32
ESP_IDF_VERSION=""      # leave empty to let espup pick the default

usage() {
  cat <<EOF
Usage: $(basename "$0") [-t <target>] [-e <esp-idf-version>]

  -t  Rust target/variant to install via espup (default: ${TARGET})
      Common values: esp32, esp32s2, esp32s3, esp32c3, esp32c6, esp32h2
  -e  ESP-IDF version to install with espup (default: espup default)
      Example: v5.2.2
  -h  Show this help message
EOF
}

while getopts "t:e:h" opt; do
  case ${opt} in
    t) TARGET="$OPTARG" ;;
    e) ESP_IDF_VERSION="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

info()  { print -P "%F{blue}[INFO]%f $*"; }
ok()    { print -P "%F{green}[OK]%f $*"; }
warn()  { print -P "%F{yellow}[WARN]%f $*"; }
error() { print -P "%F{red}[ERROR]%f $*"; }

# ---------------------------------------------------------------------------
# 1. OS check
# ---------------------------------------------------------------------------
if [[ "$(uname -s)" != "Darwin" ]]; then
  error "This script is intended for macOS."
  exit 1
fi

MAC_ARCH="$(uname -m)"
info "Detected macOS (${MAC_ARCH})."

# ---------------------------------------------------------------------------
# 2. Xcode Command Line Tools
# ---------------------------------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  warn "Xcode Command Line Tools not found. Installing..."
  xcode-select --install
  error "Please finish the Command Line Tools install, then re-run this script."
  exit 1
fi
ok "Xcode Command Line Tools present."

# ---------------------------------------------------------------------------
# 3. Homebrew
# ---------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  ok "Homebrew present."
  eval "$(brew shellenv)"
fi

# ---------------------------------------------------------------------------
# 4. Required packages for building ESP-IDF and flashing
# ---------------------------------------------------------------------------
info "Installing/upgrading required Homebrew packages..."
brew update
brew install --quiet git cmake ninja python3 ccache libusb pkg-config llvm || true
ok "Homebrew packages ready."

# ---------------------------------------------------------------------------
# 5. Rust / rustup
# ---------------------------------------------------------------------------
# Rustup may already be installed and not on PATH yet for this session.
source "${HOME}/.cargo/env" 2>/dev/null || true

if command -v rustup >/dev/null 2>&1 || [[ -x "${HOME}/.cargo/bin/rustup" ]]; then
  ok "Rust toolchain already installed ($(rustc --version 2>/dev/null || true)); skipping Rust install."
else
  info "Rust toolchain not found. Installing rustup..."

  # Prefer the Homebrew rustup-init wrapper, fall back to the official installer.
  if command -v brew >/dev/null 2>&1; then
    info "Installing rustup-init via Homebrew..."
    brew install --quiet rustup-init
    rustup-init -y --no-modify-path
  else
    info "Installing rustup from the official installer..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  fi
fi

# Make cargo/rustup available in this session after any install/upgrade
source "${HOME}/.cargo/env" 2>/dev/null || true

if ! command -v cargo >/dev/null 2>&1; then
  error "Rust/Cargo installation failed or is not on PATH."
  exit 1
fi

rustup component add rust-src 2>/dev/null || true
ok "Rust ready ($(rustc --version))."

# ---------------------------------------------------------------------------
# 6. espup — the esp-rs installer
# ---------------------------------------------------------------------------
info "Installing/updating espup..."
cargo install espup --locked --force

ESPUP_ARGS=("--targets" "${TARGET}")
if [[ -n "${ESP_IDF_VERSION}" ]]; then
  ESPUP_ARGS+=("--esp-idf-version" "${ESP_IDF_VERSION}")
fi

info "Running espup install for target '${TARGET}'..."
if ! espup install "${ESPUP_ARGS[@]}"; then
  error "espup install failed."
  exit 1
fi
ok "espup install finished."

# ---------------------------------------------------------------------------
# 7. Source the generated export script and install helper crates
# ---------------------------------------------------------------------------
EXPORT_SCRIPT="${HOME}/export-esp.sh"
if [[ ! -f "${EXPORT_SCRIPT}" ]]; then
  EXPORT_SCRIPT="${HOME}/.espressif/export-esp.sh"
fi

if [[ ! -f "${EXPORT_SCRIPT}" ]]; then
  warn "Could not find export-esp.sh; searching for it..."
  EXPORT_SCRIPT="$(find "${HOME}" -maxdepth 3 -name 'export-esp.sh' -print -quit 2>/dev/null || true)"
fi

if [[ -z "${EXPORT_SCRIPT}" || ! -f "${EXPORT_SCRIPT}" ]]; then
  error "export-esp.sh not found. espup may have failed or installed to an unexpected path."
  exit 1
fi

ok "Found ESP environment exporter at ${EXPORT_SCRIPT}."

# Load it now so cargo-targets/espflash can build with the Xtensa toolchain
set +e
source "${EXPORT_SCRIPT}"
set -e

info "Installing Rust helper crates..."
cargo install cargo-generate --locked
cargo install ldproxy --locked

# Flashing / ROM tools
cargo install espflash --locked
cargo install cargo-espflash --locked

ok "Helper crates installed."

# ---------------------------------------------------------------------------
# 8. Add an activation helper to .zshrc
# ---------------------------------------------------------------------------
ZSHRC="${HOME}/.zshrc"
ALIAS_NAME="get_esp_rust"

if ! grep -q "function ${ALIAS_NAME}()" "${ZSHRC}" 2>/dev/null; then
  info "Adding '${ALIAS_NAME}' helper to ${ZSHRC}..."
  cat <<EOF >> "${ZSHRC}"

# esp-rs / ESP-IDF Rust helper: run '${ALIAS_NAME}' to load the environment
function ${ALIAS_NAME}() {
  . "${EXPORT_SCRIPT}"
}
EOF
  ok "'${ALIAS_NAME}' helper added."
else
  warn "'${ALIAS_NAME}' helper already present in ${ZSHRC}."
fi

# ---------------------------------------------------------------------------
# 9. USB-to-UART driver note
# ---------------------------------------------------------------------------
echo
cat <<EOF
$(warn "USB-to-UART driver")
Most ESP32-WROOM dev boards use a CP2102 or CH340 USB-to-serial chip.
- CP2102 driver: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
- CH340 driver:  https://github.com/adrianmihalko/ch340g-mac-os-x-driver

After connecting the board, the serial port usually appears as:
  /dev/cu.usbserial-*     or     /dev/tty.usbserial-*
EOF

# ---------------------------------------------------------------------------
# 10. Verify and give a quick-start example
# ---------------------------------------------------------------------------
echo
info "Verifying Xtensa toolchain..."
printenv PATH
"${HOME}/.rustup/toolchains/esp/bin/rustc" --version || true

ok "ESP32 Rust development environment installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Activate the environment with: get_esp_rust"
echo "  3. Create a Wi-Fi/STD project:"
echo "       cargo generate esp-rs/esp-idf-template cargo"
echo "     When prompted, choose platform: esp32, MCU: esp32"
echo "  4. Build/flash/monitor:"
echo "       cd <project>"
echo "       cargo build --release # or"
echo "       cargo run --release   # flashes and starts monitor via espflash"
