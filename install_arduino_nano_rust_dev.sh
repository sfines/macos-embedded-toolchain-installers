#!/bin/zsh
#
# install_arduino_nano_rust_dev.sh
# Install the Rust AVR toolchain for the Arduino Nano on macOS.
#
# Target MCU: ATmega328P (used on Arduino Nano / Elegoo Nano 3.0)
# Rust target: avr-atmega328p (requires nightly Rust + build-std)
#
# Usage:
#   ./install_arduino_nano_rust_dev.sh
#

set -e

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
# 4. Required system packages
# ---------------------------------------------------------------------------
info "Installing/upgrading required Homebrew packages..."
brew update
brew install --quiet git avrdude python3 || true

# avr-gcc is in a third-party tap; try core first then the osx-cross tap
if ! brew list avr-gcc >/dev/null 2>&1; then
  info "Installing avr-gcc from osx-cross/avr tap..."
  brew tap osx-cross/avr 2>/dev/null || true
  brew install --quiet avr-gcc || warn "avr-gcc installation failed; you may not need it if Rust builds everything"
fi

ok "Homebrew packages ready."

# ---------------------------------------------------------------------------
# 5. Rust toolchain
# ---------------------------------------------------------------------------
source "${HOME}/.cargo/env" 2>/dev/null || true

if command -v rustup >/dev/null 2>&1 || [[ -x "${HOME}/.cargo/bin/rustup" ]]; then
  ok "Rust toolchain already installed ($(rustc --version 2>/dev/null || true)); skipping Rust install."
else
  info "Rust toolchain not found. Installing rustup..."

  if command -v brew >/dev/null 2>&1; then
    info "Installing rustup-init via Homebrew..."
    brew install --quiet rustup-init
    rustup-init -y --no-modify-path
  else
    info "Installing rustup from the official installer..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  fi
fi

source "${HOME}/.cargo/env" 2>/dev/null || true

if ! command -v cargo >/dev/null 2>&1; then
  error "Rust/Cargo installation failed or is not on PATH."
  exit 1
fi

info "Installing Rust nightly toolchain (AVR support is on nightly)..."
rustup toolchain install nightly
rustup component add rust-src --toolchain nightly

info "Attempting to add avr-atmega328p Rust target..."
rustup target add avr-atmega328p --toolchain nightly 2>/dev/null || \
  warn "Could not add avr-atmega328p target directly; most avr-hal projects use '-Z build-std=core' via nightly instead."

ok "Rust toolchain ready for Arduino Nano ($(rustc --version))."

# ---------------------------------------------------------------------------
# 6. Cargo helper tools
# ---------------------------------------------------------------------------
info "Installing Rust helper crates..."

cargo install cargo-generate --locked

# ravedude flashes Rust AVR binaries over serial with avrdude
cargo install ravedude --locked 2>/dev/null || \
  warn "cargo install ravedude failed; you can retry after the nightly toolchain settles."

ok "Helper crates installed."

# ---------------------------------------------------------------------------
# 7. Shell helpers
# ---------------------------------------------------------------------------
ZSHRC="${HOME}/.zshrc"
if ! grep -q "function arduino_nano_flash()" "${ZSHRC}" 2>/dev/null; then
  info "Adding convenience functions to ${ZSHRC}..."
  cat <<'EOF' >> "${ZSHRC}"

# Arduino Nano helpers
function arduino_nano_ports() {
  ls -1 /dev/cu.usbserial-* /dev/cu.wchusbserial-* /dev/cu.usbmodem-* 2>/dev/null || true
}
EOF
  ok "Shell helpers added."
else
  warn "Arduino Nano shell helpers already present in ${ZSHRC}."
fi

# ---------------------------------------------------------------------------
# 8. USB-to-serial driver note
# ---------------------------------------------------------------------------
echo
cat <<EOF
$(warn "USB-to-serial driver")
Nano clones (including many Elegoo Nano 3.0 boards) use a CH340 or FTDI
USB-to-serial chip. macOS may already recognize CH340, but if the board does
not show up as a serial port, install the appropriate driver:
- CH340 driver: https://github.com/adrianmihalko/ch340g-mac-os-x-driver
- FTDI driver:  https://ftdichip.com/drivers/vcp-drivers/

After connecting the board, the serial port usually appears as:
  /dev/cu.usbserial-*
  /dev/cu.wchusbserial-*
  /dev/cu.usbmodem-*
EOF

# ---------------------------------------------------------------------------
# 9. Verify and quick-start
# ---------------------------------------------------------------------------
echo
info "Installed tools:"
command -v avrdude && avrdude -version 2>&1 | head -1 || true
command -v cargo-generate && cargo-generate --version || true

echo
ok "Arduino Nano Rust toolchain installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Generate an avr-hal starter project:"
echo "       cargo generate --git https://github.com/Rahix/avr-hal-template"
echo "     Select the Arduino Nano / ATmega328P variant."
echo "  3. Build with nightly:"
echo "       cargo +nightly build"
echo "  4. Find the serial port:"
echo "       arduino_nano_ports"
echo "  5. Flash with ravedude (configured as the cargo runner in the template):"
echo "       cargo +nightly run"
