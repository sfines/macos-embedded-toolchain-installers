#!/bin/zsh
#
# install_rp2350_platformio_dev.sh
# Install the PlatformIO toolchain for RP2350 boards on macOS.
#
# Example board: Raspberry Pi Pico 2
# PlatformIO platform support for RP2350 ships via the raspberrypi platform and
# associated board definitions as they become available.
#
# Usage:
#   ./install_rp2350_platformio_dev.sh
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
brew install --quiet python3 git libusb || true
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
# 8. Install the Raspberry Pi platform
# ---------------------------------------------------------------------------
info "Installing the raspberrypi platform..."
pio platform install raspberrypi || \
  warn "raspberrypi platform install had issues; RP2350 board definitions may need to be added manually."
ok "raspberrypi platform step finished."

# ---------------------------------------------------------------------------
# 9. Optional shell completion
# ---------------------------------------------------------------------------
if ! grep -q "pio completion install" "${ZSHRC}" 2>/dev/null; then
  info "Installing PlatformIO shell completion..."
  pio completion install zsh 2>/dev/null || warn "pio completion install failed; continuing..."
fi

# ---------------------------------------------------------------------------
# 10. BOOTSEL / upload note
# ---------------------------------------------------------------------------
echo
cat <<EOF
$(warn "RP2350 upload note")
RP2350 uses the same UF2 BOOTSEL bootloader as RP2040. To upload with
PlatformIO:

  1. Hold the BOOTSEL button.
  2. Plug in the board (or press RESET).
  3. Release BOOTSEL.
  4. Run: pio run -t upload

The board appears as a drive named "RPI-RP2".

Board definitions for the Pico 2 and other RP2350 boards may not yet be in the
stable platform package; if `pio run -t upload` fails with an unknown board,
check the PlatformIO registry for an updated board ID or use `board = pico2`
once available.
EOF

# ---------------------------------------------------------------------------
# 11. Verify and quick-start
# ---------------------------------------------------------------------------
echo
info "PlatformIO version:"
pio --version

echo
ok "RP2350 PlatformIO toolchain installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. List available RP2350 boards:"
echo "       pio boards raspberrypi | grep -i rp2350"
echo "       pio boards raspberrypi | grep -i pico2"
echo "  3. Create a project once the board is known, e.g.:"
echo "       pio project init --board <board-id> --project-dir ~/rp2350-blink"
echo "  4. Build/flash/monitor:"
echo "       cd ~/rp2350-blink"
echo "       pio run"
echo "       pio run -t upload    # put board in BOOTSEL mode first"
echo "       pio device monitor"
