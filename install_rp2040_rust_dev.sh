#!/bin/zsh
#
# install_rp2040_rust_dev.sh
# Install the Rust embedded toolchain for RP2040 boards (e.g. Raspberry Pi Pico)
# on macOS.
#
# Target MCU: Raspberry Pi RP2040 (dual-core ARM Cortex-M0+)
# Rust target: thumbv6m-none-eabi
# Programmers: USB BOOTSEL/UF2 (drag-and-drop), or SWD via probe-rs
#
# Usage:
#   ./install_rp2040_rust_dev.sh
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
brew install --quiet git cmake ninja python3 libusb pkg-config minicom || true
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

info "Adding ARM Cortex-M0+ Rust target..."
rustup target add thumbv6m-none-eabi

info "Adding required rustup components..."
rustup component add llvm-tools-preview rust-src 2>/dev/null || true

ok "Rust toolchain ready for RP2040 ($(rustc --version))."

# ---------------------------------------------------------------------------
# 6. Cargo helper tools
# ---------------------------------------------------------------------------
info "Installing Rust embedded helper crates (this may take a few minutes)..."

cargo install cargo-generate --locked
cargo install cargo-binutils --locked
cargo install flip-link --locked
cargo install cargo-bloat --locked 2>/dev/null || true

# UF2 conversion / drag-and-drop deploy for BOOTSEL mode
cargo install elf2uf2-rs --locked

# SWD debug/flash support via probe-rs
cargo install probe-rs-tools --locked 2>/dev/null || \
  warn "probe-rs-tools build failed; you can still use UF2 / elf2uf2-rs for flashing."

ok "Helper crates installed."

# ---------------------------------------------------------------------------
# 7. Shell helpers
# ---------------------------------------------------------------------------
ZSHRC="${HOME}/.zshrc"
if ! grep -q "function rp2040_probe()" "${ZSHRC}" 2>/dev/null; then
  info "Adding convenience functions to ${ZSHRC}..."
  cat <<'EOF' >> "${ZSHRC}"

# RP2040 helpers
function rp2040_probe() {
  command -v probe-rs >/dev/null 2>&1 && probe-rs list || echo "probe-rs not available"
}

function rp2040_uf2_drives() {
  find /Volumes -maxdepth 1 -iname 'RPI-RP2*' -print 2>/dev/null || true
}
EOF
  ok "Shell helpers added."
else
  warn "RP2040 shell helpers already present in ${ZSHRC}."
fi

# ---------------------------------------------------------------------------
# 8. BOOTSEL / SWD note
# ---------------------------------------------------------------------------
echo
cat <<EOF
$(warn "RP2040 programming note")
The easiest way to flash an RP2040 is via USB BOOTSEL mode:

  1. Hold the BOOTSEL button on the board.
  2. Plug in (or press RESET for built-in-USB boards).
  3. Release BOOTSEL.
  4. The board appears as a drive named "RPI-RP2".

cargo will then automatically convert the ELF to a UF2 and copy it over if
your project's runner is set to elf2uf2-rs.

For debugging, attach an SWD probe (Raspberry Pi Debug Probe, Picoprobe,
ST-Link, etc.) and use probe-rs / cargo-embed.
EOF

# ---------------------------------------------------------------------------
# 9. Verify and quick-start
# ---------------------------------------------------------------------------
echo
info "Installed tools:"
command -v cargo-generate && cargo-generate --version || true
command -v cargo-size && cargo-size --version || true
command -v elf2uf2-rs && elf2uf2-rs --version || true
command -v probe-rs && probe-rs --version || true

echo
ok "RP2040 Rust toolchain installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Generate an rp-hal starter project:"
echo "       cargo generate --git https://github.com/rp-rs/rp2040-project-template"
echo "     For the Raspberry Pi Pico, choose board = 'rp-pico' when prompted."
echo "  3. Build (the template's runner will create a UF2):"
echo "       cargo build --release"
echo "  4. Put the board in BOOTSEL mode, then run:"
echo "       cargo run --release"
echo "  5. Or manually deploy a UF2:"
echo "       elf2uf2-rs target/thumbv6m-none-eabi/release/<binary> /Volumes/RPI-RP2/app.uf2"
