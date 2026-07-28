#!/bin/zsh
#
# install_esp32_platformio_dev.sh
# Install the PlatformIO ecosystem for ESP32-WROOM development on macOS.
#
# Usage:
#   ./install_esp32_platformio_dev.sh
#

set -e

PIO_PENV="${HOME}/.platformio/penv"

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

info "Detected macOS ($(uname -m))."

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
# 4. Required packages
# ---------------------------------------------------------------------------
info "Installing/upgrading required Homebrew packages..."
brew update
brew install --quiet python3 git || true
ok "Homebrew packages ready."

# ---------------------------------------------------------------------------
# 5. Python3
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  error "python3 is required but not available."
  exit 1
fi

python3 -m ensurepip --upgrade 2>/dev/null || true
python3 -m pip install --upgrade pip setuptools wheel 2>/dev/null || true
ok "Python3 ready ($(python3 --version))."

# ---------------------------------------------------------------------------
# 6. PlatformIO Core into an isolated virtualenv
# ---------------------------------------------------------------------------
if [[ -d "${PIO_PENV}" ]]; then
  info "Existing PlatformIO virtualenv found; upgrading PlatformIO..."
  "${PIO_PENV}/bin/pip" install -U platformio
else
  info "Creating PlatformIO virtualenv and installing PlatformIO Core..."
  python3 -m venv "${PIO_PENV}"
  "${PIO_PENV}/bin/pip" install -U platformio
fi

if [[ ! -x "${PIO_PENV}/bin/pio" ]]; then
  error "PlatformIO installation failed."
  exit 1
fi
ok "PlatformIO Core installed."

# ---------------------------------------------------------------------------
# 7. Add PlatformIO to PATH / shell helpers
# ---------------------------------------------------------------------------
ZSHRC="${HOME}/.zshrc"
PATH_LINE='export PATH="${HOME}/.platformio/penv/bin:${PATH}"'

if ! grep -qF "${PATH_LINE}" "${ZSHRC}" 2>/dev/null; then
  info "Adding PlatformIO to PATH in ${ZSHRC}..."
  cat >> "${ZSHRC}" <<EOF

# PlatformIO
${PATH_LINE}
EOF
fi

# Load for the rest of this script
export PATH="${PIO_PENV}/bin:${PATH}"

# ---------------------------------------------------------------------------
# 8. Install the Espressif 32 platform
# ---------------------------------------------------------------------------
info "Installing the espressif32 platform..."
pio platform install espressif32
ok "espressif32 platform installed."

# ---------------------------------------------------------------------------
# 9. Optional shell completion
# ---------------------------------------------------------------------------
if ! grep -q "pio completion install" "${ZSHRC}" 2>/dev/null; then
  info "Installing PlatformIO shell completion..."
  pio completion install zsh 2>/dev/null || warn "pio completion install failed; continuing..."
fi

# ---------------------------------------------------------------------------
# 10. USB-to-UART driver note
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
# 11. Verify and quick-start
# ---------------------------------------------------------------------------
echo
info "PlatformIO version:"
pio --version

ok "ESP32-WROOM PlatformIO development environment installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Create an ESP32 project:"
echo "       pio project init --board esp32dev --project-dir ~/esp32-blink"
echo "  3. Build/flash/monitor:"
echo "       cd ~/esp32-blink"
echo "       pio run"
echo "       pio run -t upload"
echo "       pio device monitor"
