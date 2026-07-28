#!/bin/zsh
#
# install_teensy41_rust_dev.sh
# Install the Rust embedded toolchain for the Teensy 4.1 on macOS.
#
# Target MCU: NXP i.MX RT1062 (ARM Cortex-M7F)
# Rust target: thumbv7em-none-eabihf (hard-float)
# Loader: Teensy HalfKay bootloader via teensy_loader_cli
#
# Usage:
#   ./install_teensy41_rust_dev.sh
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
brew install --quiet git cmake ninja python3 libusb libusb-compat pkg-config || true
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

ok "Rust toolchain ready for Teensy 4.1 ($(rustc --version))."

# ---------------------------------------------------------------------------
# 6. Cargo helper tools
# ---------------------------------------------------------------------------
info "Installing Rust helper crates..."

cargo install cargo-generate --locked
cargo install cargo-binutils --locked
cargo install flip-link --locked 2>/dev/null || true

ok "Helper crates installed."

# ---------------------------------------------------------------------------
# 7. teensy_loader_cli (HalfKay bootloader uploader)
# ---------------------------------------------------------------------------
if command -v teensy_loader_cli >/dev/null 2>&1; then
  ok "teensy_loader_cli already installed."
else
  info "Building teensy_loader_cli from source..."
  TMP_DIR="$(mktemp -d)"
  git clone --depth 1 https://github.com/PaulStoffregen/teensy_loader_cli.git "${TMP_DIR}"
  cd "${TMP_DIR}"

  USB_PREFIX="$(brew --prefix libusb-compat)"
  make clean 2>/dev/null || true
  make OS=MACOSX \
    CC=clang \
    CFLAGS="-Wall -O2 -mmacosx-version-min=10.11 -I${USB_PREFIX}/include" \
    LDFLAGS="-O2 -mmacosx-version-min=10.11 -L${USB_PREFIX}/lib"

  if [[ -x ./teensy_loader_cli ]]; then
    cp ./teensy_loader_cli "${LOCAL_BIN}/teensy_loader_cli"
    chmod +x "${LOCAL_BIN}/teensy_loader_cli"
    ok "teensy_loader_cli installed to ${LOCAL_BIN}/teensy_loader_cli"
  else
    warn "teensy_loader_cli build failed; you can install the Teensy Loader app manually."
  fi

  cd -
  rm -rf "${TMP_DIR}"
fi

# ---------------------------------------------------------------------------
# 8. Shell helpers
# ---------------------------------------------------------------------------
if ! grep -q "function teensy41_flash()" "${ZSHRC}" 2>/dev/null; then
  info "Adding convenience functions to ${ZSHRC}..."
  cat <<'EOF' >> "${ZSHRC}"

# Teensy 4.1 helpers
function teensy41_ports() {
  ls -1 /dev/cu.usbmodem-* 2>/dev/null || true
}

function teensy41_loader() {
  command -v teensy_loader_cli >/dev/null 2>&1 || { echo "teensy_loader_cli not on PATH"; return 1; }
  teensy_loader_cli --mcu=imxrt1062 "$@"
}
EOF
  ok "Shell helpers added."
else
  warn "Teensy 4.1 shell helpers already present in ${ZSHRC}."
fi

# ---------------------------------------------------------------------------
# 9. Verify and quick-start
# ---------------------------------------------------------------------------
echo
info "Installed tools:"
command -v cargo-generate && cargo-generate --version || true
command -v cargo-size && cargo-size --version || true
command -v teensy_loader_cli && teensy_loader_cli --help 2>&1 | head -3 || true

echo
ok "Teensy 4.1 Rust toolchain installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Clone the teensy4-rs examples:"
echo "       git clone https://github.com/imxrt-rs/teensy4-rs"
echo "       cd teensy4-rs"
echo "  3. Build an example:"
echo "       cargo build --release --example blinky"
echo "  4. Flash with the installed loader:"
echo "       teensy41_loader -w -v target/thumbv7em-none-eabihf/release/examples/blinky.hex"

echo
cat <<EOF
$(warn "Note")
The Teensy 4.1 uses a proprietary HalfKay bootloader over USB. This installer
builds Paul Stoffregen's teensy_loader_cli and places it in ${LOCAL_BIN}.
Many Rust projects use it as the cargo runner; otherwise flash manually with:
  teensy41_loader -w -v target/thumbv7em-none-eabihf/release/<binary>.hex

If the command-line uploader gives you trouble, the graphical Teensy Loader app
from https://www.pjrc.com/teensy/loader.html always works.
EOF
