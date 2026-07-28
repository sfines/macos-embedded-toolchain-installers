#!/bin/zsh
#
# install_microbit_v2_rust_dev.sh
# Install the Rust embedded toolchain for the micro:bit v2 on macOS.
#
# Target MCU: Nordic nRF52833 (Cortex-M4F)
# Rust target: thumbv7em-none-eabihf (hard-float)
# Debugger: on-board CMSIS-DAP / DAPLink interface
#
# Usage:
#   ./install_microbit_v2_rust_dev.sh
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
brew install --quiet git cmake ninja python3 libusb pkg-config openocd minicom || true
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

info "Adding ARM Cortex-M4F Rust targets..."
rustup target add thumbv7em-none-eabihf
rustup target add thumbv7em-none-eabi 2>/dev/null || true

info "Adding required rustup components..."
rustup component add llvm-tools-preview rust-src 2>/dev/null || true

ok "Rust toolchain ready for micro:bit v2 ($(rustc --version))."

# ---------------------------------------------------------------------------
# 6. Cargo helper tools
# ---------------------------------------------------------------------------
info "Installing Rust embedded helper crates (this may take a few minutes)..."

cargo install cargo-generate --locked
cargo install cargo-binutils --locked
cargo install flip-link --locked
cargo install cargo-bloat --locked 2>/dev/null || true

# probe-rs gives us probe-rs, cargo-embed, and cargo-flash (supports CMSIS-DAP/DAPLink)
cargo install probe-rs-tools --locked

ok "Helper crates installed."

# ---------------------------------------------------------------------------
# 7. Shell helpers
# ---------------------------------------------------------------------------
ZSHRC="${HOME}/.zshrc"
if ! grep -q "function microbit_probe()" "${ZSHRC}" 2>/dev/null; then
  info "Adding convenience functions to ${ZSHRC}..."
  cat <<'EOF' >> "${ZSHRC}"

# micro:bit v2 helpers
function microbit_probe() {
  probe-rs list
}

function microbit_chips() {
  probe-rs chip list | grep -i nrf52833
}
EOF
  ok "Shell helpers added."
else
  warn "micro:bit v2 shell helpers already present in ${ZSHRC}."
fi

# ---------------------------------------------------------------------------
# 8. DAPLink / USB note
# ---------------------------------------------------------------------------
echo
cat <<EOF
$(warn "DAPLink / USB note")
The micro:bit v2 has an on-board CMSIS-DAP/DAPLink interface. macOS does not
need a separate kernel driver; libusb and probe-rs installed above will talk to
it directly.

Verify the probe is detected:
  probe-rs list

To see the exact nRF52833 chip name to use with probe-rs:
  microbit_chips
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
ok "micro:bit v2 Rust toolchain installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Generate a starter project:"
echo "       cargo generate --git https://github.com/rust-embedded/cortex-m-quickstart"
echo "     Then adapt memory.x for the nRF52833 (Flash 512 KiB, RAM 128 KiB)"
echo "     and add the nrf52833-hal / microbit crate as needed."
echo "  3. Build:"
echo "       cargo build --target thumbv7em-none-eabihf"
echo "  4. Find the nRF52833 chip name:"
echo "       microbit_chips"
echo "  5. Flash with probe-rs (example chip name):"
echo "       cargo flash --chip nRF52833_xxAA --target thumbv7em-none-eabihf"
echo "  6. Or use cargo-embed for RTT logging:"
echo "       cargo embed --target thumbv7em-none-eabihf --chip nRF52833_xxAA"
