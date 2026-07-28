#!/bin/zsh
#
# install_daisy_seed_rust_dev.sh
# Install the Rust embedded toolchain for the Daisy Seed on macOS.
#
# Target MCU: STM32H750IBK6 (ARM Cortex-M7F)
# Rust target: thumbv7em-none-eabihf (hard-float)
# Programmers: USB DFU bootloader, or external ST-Link on the SWD header
#
# Usage:
#   ./install_daisy_seed_rust_dev.sh
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
brew install --quiet git cmake ninja python3 libusb pkg-config dfu-util stlink minicom || true
ok "Homebrew packages ready."

# Ensure ~/.local/bin is on PATH
LOCAL_BIN="${HOME}/.local/bin"
mkdir -p "${LOCAL_BIN}"
ZSHRC="${HOME}/.zshrc"
if ! grep -qF 'export PATH="${HOME}/.local/bin:${PATH}"' "${ZSHRC}" 2>/dev/null; then
  info "Adding ~/.local/bin to PATH in ${ZSHRC}..."
  cat >> "${ZSHRC}" <<'EOF'

# User-local binaries
export PATH="${HOME}/.local/bin:${PATH}"
EOF
fi
export PATH="${LOCAL_BIN}:${PATH}"

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

info "Adding ARM Cortex-M7F Rust target..."
rustup target add thumbv7em-none-eabihf

info "Adding required rustup components..."
rustup component add llvm-tools-preview rust-src 2>/dev/null || true

ok "Rust toolchain ready for Daisy Seed ($(rustc --version))."

# ---------------------------------------------------------------------------
# 6. Cargo helper tools
# ---------------------------------------------------------------------------
info "Installing Rust embedded helper crates (this may take a few minutes)..."

cargo install cargo-generate --locked
cargo install cargo-binutils --locked
cargo install flip-link --locked
cargo install cargo-bloat --locked 2>/dev/null || true

# External ST-Link / debug probe support
cargo install probe-rs-tools --locked 2>/dev/null || \
  warn "probe-rs-tools build failed; you can still use the USB DFU bootloader."

# USB DFU bootloader support
cargo install cargo-dfu --locked 2>/dev/null || \
  warn "cargo-dfu build failed; dfu-util is installed as a fallback."

ok "Helper crates installed."

# ---------------------------------------------------------------------------
# 7. Shell helpers
# ---------------------------------------------------------------------------
if ! grep -q "function daisy_seed_probe()" "${ZSHRC}" 2>/dev/null; then
  info "Adding convenience functions to ${ZSHRC}..."
  cat <<'EOF' >> "${ZSHRC}"

# Daisy Seed helpers
function daisy_seed_probe() {
  command -v probe-rs >/dev/null 2>&1 && probe-rs list || echo "probe-rs not available"
}

function daisy_seed_dfu_list() {
  dfu-util --list
}

function daisy_seed_ports() {
  ls -1 /dev/cu.usbserial-* /dev/cu.usbmodem-* 2>/dev/null || true
}
EOF
  ok "Shell helpers added."
else
  warn "Daisy Seed shell helpers already present in ${ZSHRC}."
fi

# ---------------------------------------------------------------------------
# 8. DFU / SWD note
# ---------------------------------------------------------------------------
echo
cat <<EOF
$(warn "Daisy Seed programming note")
The Daisy Seed can be programmed in two ways:

1. USB DFU bootloader (simplest, no extra hardware):
   - Hold BOOT, press RESET, release RESET, then release BOOT.
   - The board appears as a DFU device.
   - This installer provides cargo-dfu and dfu-util.

2. External ST-Link on the SWD header:
   - Connect an ST-Link V2/V3 to the SWD pins.
   - This installer provides probe-rs / cargo-embed.
EOF

# ---------------------------------------------------------------------------
# 9. Verify and quick-start
# ---------------------------------------------------------------------------
echo
info "Installed tools:"
command -v cargo-generate && cargo-generate --version || true
command -v cargo-size && cargo-size --version || true
command -v dfu-util && dfu-util --version 2>&1 | head -1 || true
command -v probe-rs && probe-rs --version || true

echo
ok "Daisy Seed Rust toolchain installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Generate a starter project:"
echo "       cargo generate --git https://github.com/rust-embedded/cortex-m-quickstart"
echo "     Then configure it for STM32H750 (Flash 128 KiB, RAM ~1 MiB including TCM)"
echo "     using stm32h7xx-hal or a Daisy BSP crate."
echo "  3. Build:"
echo "       cargo build --release --target thumbv7em-none-eabihf"
echo "  4. List DFU devices (put the board in DFU mode first):"
echo "       daisy_seed_dfu_list"
echo "  5. Flash via DFU (example; address depends on project/linker script):"
echo "       cargo dfu --release"
echo "     # or with dfu-util:"
echo "       dfu-util -a 0 -s 0x08000000:leave -D target/thumbv7em-none-eabihf/release/app.bin"
