#!/bin/zsh
#
# install_daisy_seed_platformio_dev.sh
# Install the PlatformIO toolchain for the Daisy Seed on macOS.
#
# Target board: Daisy Seed (Electro-Smith)
# Target MCU: STM32H750IBK6
# PlatformIO platform: ststm32
# PlatformIO board ID: daisy_seed
# Upload: USB DFU (default) or external ST-Link
#
# Usage:
#   ./install_daisy_seed_platformio_dev.sh
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
brew install --quiet python3 git libusb dfu-util || true
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

export PATH="${PIO_PENV}/bin:${PATH}"

# ---------------------------------------------------------------------------
# 8. Install the ST STM32 platform
# ---------------------------------------------------------------------------
info "Installing the ststm32 platform..."
pio platform install ststm32
ok "ststm32 platform installed."

# ---------------------------------------------------------------------------
# 9. Optional shell completion
# ---------------------------------------------------------------------------
if ! grep -q "pio completion install" "${ZSHRC}" 2>/dev/null; then
  info "Installing PlatformIO shell completion..."
  pio completion install zsh 2>/dev/null || warn "pio completion install failed; continuing..."
fi

# ---------------------------------------------------------------------------
# 10. DFU note
# ---------------------------------------------------------------------------
echo
cat <<EOF
$(warn "Daisy Seed DFU note")
PlatformIO will use the Daisy Seed's USB DFU bootloader by default. To enter
DFU mode:

  1. Hold the BOOT button.
  2. Press and release the RESET button.
  3. Release the BOOT button.

Then run upload with:
  pio run -t upload

If you prefer to use an external ST-Link, set upload_protocol = stlink in
platformio.ini.
EOF

# ---------------------------------------------------------------------------
# 11. Verify and quick-start
# ---------------------------------------------------------------------------
echo
info "PlatformIO version:"
pio --version

echo
ok "Daisy Seed PlatformIO toolchain installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Create a Daisy Seed project:"
echo "       pio project init --board daisy_seed --project-dir ~/daisy-blink"
echo "  3. Build/flash/monitor:"
echo "       cd ~/daisy-blink"
echo "       pio run"
echo "       pio run -t upload    # put board in DFU mode first"
echo "       pio device monitor"
