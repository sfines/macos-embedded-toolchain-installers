#!/bin/zsh
#
# install_esp32_dev.sh
# Install the Espressif ESP-IDF toolchain for ESP32-WROOM development on macOS.
#
# Usage:
#   ./install_esp32_dev.sh [-v <esp-idf-version>] [-p <install-path>]
#
# Examples:
#   ./install_esp32_dev.sh
#   ./install_esp32_dev.sh -v v5.2.2 -p ~/esp
#

set -e

# Defaults
IDF_VERSION="v5.2.2"
INSTALL_PATH="${HOME}/esp"
TARGETS="esp32"   # ESP32-WROOM-32 is an ESP32 target

usage() {
  cat <<EOF
Usage: $(basename "$0") [-v <esp-idf-version>] [-p <install-path>]

  -v  ESP-IDF version to install (default: ${IDF_VERSION})
  -p  Directory where esp-idf will be cloned (default: ${INSTALL_PATH})
  -h  Show this help message
EOF
}

while getopts "v:p:h" opt; do
  case ${opt} in
    v) IDF_VERSION="$OPTARG" ;;
    p) INSTALL_PATH="$OPTARG" ;;
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
else
  ok "Xcode Command Line Tools present."
fi

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
# 4. Required packages
# ---------------------------------------------------------------------------
info "Installing/upgrading required Homebrew packages..."
brew update

# Core build tools
brew install --quiet git cmake ninja python3 ccache || true

# Tools used by some ESP-IDF components / optional but recommended
brew install --quiet wget flex bison gperf libffi openssl xz || true

ok "Homebrew packages ready."

# ---------------------------------------------------------------------------
# 5. Python3 & pip
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  error "python3 is required but not installed."
  exit 1
fi

python3 -m ensurepip --upgrade 2>/dev/null || true
python3 -m pip install --upgrade pip setuptools wheel virtualenv 2>/dev/null || true
ok "Python3/pip ready ($(python3 --version))."

# ---------------------------------------------------------------------------
# 6. Clone / update ESP-IDF
# ---------------------------------------------------------------------------
IDF_DIR="${INSTALL_PATH}/esp-idf"

mkdir -p "${INSTALL_PATH}"

if [[ -d "${IDF_DIR}/.git" ]]; then
  info "Existing ESP-IDF repo found at ${IDF_DIR}. Updating to ${IDF_VERSION}..."
  cd "${IDF_DIR}"
  git fetch origin
  git checkout "${IDF_VERSION}"
  git submodule update --init --recursive
else
  info "Cloning ESP-IDF ${IDF_VERSION} into ${IDF_DIR}..."
  git clone -b "${IDF_VERSION}" --recursive https://github.com/espressif/esp-idf.git "${IDF_DIR}"
  cd "${IDF_DIR}"
fi

ok "ESP-IDF source ready at ${IDF_DIR}."

# ---------------------------------------------------------------------------
# 7. Install ESP-IDF toolchain
# ---------------------------------------------------------------------------
info "Installing ESP-IDF tools for target(s): ${TARGETS}..."
./install.sh "${TARGETS}"

ok "ESP-IDF tools installed."

# ---------------------------------------------------------------------------
# 8. Create convenient activation function for .zshrc
# ---------------------------------------------------------------------------
ZSHRC="${HOME}/.zshrc"
ALIAS_NAME="get_idf"

if ! grep -q "function ${ALIAS_NAME}()" "${ZSHRC}" 2>/dev/null; then
  info "Adding '${ALIAS_NAME}' helper to ${ZSHRC}..."
  cat <<EOF >> "${ZSHRC}"

# ESP-IDF helper: run 'get_idf' to load ESP-IDF environment
function get_idf() {
  export IDF_PATH="${IDF_DIR}"
  . "${IDF_DIR}/export.sh"
}
EOF
  ok "'get_idf' helper added. Open a new terminal or run: source ~/.zshrc"
else
  warn "'get_idf' helper already present in ${ZSHRC}."
fi

# ---------------------------------------------------------------------------
# 9. Recommended USB-to-UART driver note
# ---------------------------------------------------------------------------
echo
cat <<EOF
$(warn "USB-to-UART driver")
Most ESP32-WROOM dev boards use either the CP2102 (Silicon Labs) or CH340 chip.
- CP2102 driver: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
- CH340 driver:  https://github.com/adrianmihalko/ch340g-mac-os-x-driver
macOS Ventura/Sonoma often includes a CH340 driver, but some boards still need the
open-source driver above.

After connecting the board, the serial port usually appears as:
  /dev/cu.usbserial-*     or     /dev/tty.usbserial-*
EOF

# ---------------------------------------------------------------------------
# 10. Verify
# ---------------------------------------------------------------------------
echo
info "Activating ESP-IDF environment to verify installation..."
. "${IDF_DIR}/export.sh"

info "ESP-IDF version:"
idf.py --version

echo
ok "ESP32-WROOM (ESP32) development environment installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Activate the environment with: get_idf"
echo "  3. Test with a sample:"
echo "       cd ~/esp/esp-idf/examples/get-started/blink"
echo "       idf.py set-target esp32"
echo "       idf.py menuconfig"
echo "       idf.py build"
echo "       idf.py -p /dev/tty.usbserial-0001 flash monitor"
