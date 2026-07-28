#!/bin/zsh
#
# install_stm32f4_discovery_rust_dev.sh
# Install the Rust embedded toolchain for the STM32F4 Discovery board on macOS.
#
# Target MCU: STM32F407VG (Cortex-M4F)
# Rust target: thumbv7em-none-eabihf (hard-float)
#
# Usage:
#   ./install_stm32f4_discovery_rust_dev.sh
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
brew install --quiet git cmake ninja python3 libusb pkg-config openocd stlink minicom || true
ok "Homebrew packages ready."

# ---------------------------------------------------------------------------
# 5. Rust toolchain
# ---------------------------------------------------------------------------
# Rustup may already be installed and not on PATH yet for this session.
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

info "Adding ARM Cortex-M4F Rust targets..."
rustup target add thumbv7em-none-eabihf
rustup target add thumbv7em-none-eabi 2>/dev/null || true

info "Adding required rustup components..."
rustup component add llvm-tools-preview rust-src 2>/dev/null || true

ok "Rust toolchain ready for STM32F4 ($(rustc --version))."

# ---------------------------------------------------------------------------
# 6. Cargo helper tools
# ---------------------------------------------------------------------------
info "Installing Rust embedded helper crates (this may take a few minutes)..."

cargo install cargo-generate --locked
cargo install cargo-binutils --locked
cargo install flip-link --locked
cargo install cargo-bloat --locked 2>/dev/null || true

# probe-rs gives us probe-rs, cargo-embed, and cargo-flash
cargo install probe-rs-tools --locked

ok "Helper crates installed."

# ---------------------------------------------------------------------------
# 7. Shell helpers
# ---------------------------------------------------------------------------
ZSHRC="${HOME}/.zshrc"
if ! grep -q "function stlink_probe()" "${ZSHRC}" 2>/dev/null; then
  info "Adding convenience functions to ${ZSHRC}..."
  cat <<'EOF' >> "${ZSHRC}"

# STM32F4 Discovery helpers
function stlink_probe() {
  local cmd="${1:-probe-rs}"
  if [[ "$cmd" == "st-info" ]]; then
    st-info --probe
  else
    probe-rs list
  fi
}

function stm32f4_openocd() {
  openocd -f board/stm32f4discovery.cfg
}
EOF
  ok "Shell helpers added."
else
  warn "STM32F4 shell helpers already present in ${ZSHRC}."
fi

# ---------------------------------------------------------------------------
# 8. ST-Link / USB note
# ---------------------------------------------------------------------------
echo
cat <<EOF
$(warn "ST-Link / USB note")
The STM32F4 Discovery has an on-board ST-Link V2 debugger/programmer.
macOS does not need a separate kernel driver for ST-Link; the Homebrew
libusb/openocd/stlink tools installed above should see it out of the box.

Verify the probe is detected:
  probe-rs list
  # or
  st-info --probe
EOF

# ---------------------------------------------------------------------------
# 9. Verify and quick-start
# ---------------------------------------------------------------------------
echo
info "Installed tools:"
command -v cargo-generate && cargo-generate --version || true
command -v cargo-size && cargo-size --version || true
command -v probe-rs && probe-rs --version || true

echo
ok "STM32F4 Discovery Rust toolchain installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Generate a starter project:"
echo "       cargo generate --git https://github.com/rust-embedded/cortex-m-quickstart"
echo "     Then edit Cargo.toml memory.x for STM32F407VG (Flash 1 MiB, RAM 192 KiB)."
echo "  3. Set the default target:"
echo "       rustup target add thumbv7em-none-eabihf"
echo "  4. Build:"
echo "       cargo build --target thumbv7em-none-eabihf"
echo "  5. Flash with probe-rs:"
echo "       cargo flash --chip STM32F407VG --target thumbv7em-none-eabihf"
echo "  6. Or use cargo-embed for RTT logging:"
echo "       cargo embed --target thumbv7em-none-eabihf --chip STM32F407VG"
echo "  7. Or debug with OpenOCD:"
echo "       stm32f4_openocd"
