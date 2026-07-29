#!/bin/zsh
#
# install_rp2350_rust_dev.sh
# Install the Rust embedded toolchain for RP2350 boards on macOS.
#
# Target MCU: Raspberry Pi RP2350 (dual-core Cortex-M33 or Hazard3)
# Common boards: Raspberry Pi Pico 2
# Rust targets: thumbv8m.main-none-eabihf (Cortex-M33 hard-float)
#                or thumbv8m.main-none-eabi (soft-float)
# Programmers: USB BOOTSEL/UF2, or SWD via probe-rs (RP2350 support is actively
#               improving in probe-rs; use the latest release)
#
# Usage:
#   ./install_rp2350_rust_dev.sh
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

info "Adding ARM Cortex-M33 Rust targets..."
rustup target add thumbv8m.main-none-eabihf
rustup target add thumbv8m.main-none-eabi 2>/dev/null || true

info "Adding required rustup components..."
rustup component add llvm-tools-preview rust-src 2>/dev/null || true

ok "Rust toolchain ready for RP2350 ($(rustc --version))."

# ---------------------------------------------------------------------------
# 6. Cargo helper tools
# ---------------------------------------------------------------------------
info "Installing Rust embedded helper crates (this may take a few minutes)..."

cargo install cargo-generate --locked
cargo install cargo-binutils --locked
cargo install flip-link --locked
cargo install cargo-bloat --locked 2>/dev/null || true

# UF2 conversion for BOOTSEL mode
cargo install elf2uf2-rs --locked

# SWD debug/flash support (RP2350 support is new; build --force to get latest)
cargo install probe-rs-tools --locked --force 2>/dev/null || \
  warn "probe-rs-tools build failed; use UF2 / elf2uf2-rs for flashing."

ok "Helper crates installed."

# ---------------------------------------------------------------------------
# 7. Shell helpers
# ---------------------------------------------------------------------------
ZSHRC="${HOME}/.zshrc"
if ! grep -q "function rp2350_probe()" "${ZSHRC}" 2>/dev/null; then
  info "Adding convenience functions to ${ZSHRC}..."
  cat <<'EOF' >> "${ZSHRC}"

# RP2350 helpers
function rp2350_probe() {
  command -v probe-rs >/dev/null 2>&1 && probe-rs list || echo "probe-rs not available"
}

function rp2350_uf2_drives() {
  find /Volumes -maxdepth 1 -iname 'RPI-RP2*' -print 2>/dev/null || true
}
EOF
  ok "Shell helpers added."
else
  warn "RP2350 shell helpers already present in ${ZSHRC}."
fi

# ---------------------------------------------------------------------------
# 8. BOOTSEL / SWD note
# ---------------------------------------------------------------------------
echo
cat <<EOF
$(warn "RP2350 programming note")
RP2350's simplest flash method is the same UF2 BOOTSEL workflow as RP2040:

  1. Hold the BOOTSEL button on the board.
  2. Plug in (or press RESET).
  3. Release BOOTSEL.
  4. The board appears as a drive named "RPI-RP2".

Many Rust starter templates will use elf2uf2-rs as the cargo runner and copy
the UF2 onto that drive automatically when you run: cargo run --release.

SWD debugging is also supported; RP2350 probe support is recent, so use the
latest probe-rs release (installed above with --force).
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
ok "RP2350 Rust toolchain installed successfully!"
echo
info "Next steps:"
echo "  1. Open a new terminal or run: source ~/.zshrc"
echo "  2. Generate or clone an RP2350 starter project:"
echo "       cargo generate --git https://github.com/rp-rs/rp2350-project-template"
echo "     (If a 2350 template doesn't exist yet, start from the rp2040 template"
echo "      and update target to thumbv8m.main-none-eabihf and hal to rp235x-hal.)"
echo "  3. Build:"
echo "       cargo build --release --target thumbv8m.main-none-eabihf"
echo "  4. Put the board in BOOTSEL mode, then run:"
echo "       cargo run --release"
