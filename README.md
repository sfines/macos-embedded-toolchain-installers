# macOS Embedded Toolchain Installers

A small collection of opinionated `zsh` installer scripts for setting up embedded-development toolchains on macOS.

All scripts assume a reasonably modern macOS machine (Intel or Apple Silicon) with the user running as an administrator-ish account. They install/use [Homebrew](https://brew.sh) where needed and avoid global root-owned installs.

## Toolchains

### ESP32-WROOM

| Script | Purpose |
|--------|---------|
| [`install_esp32_dev.sh`](./install_esp32_dev.sh) | Espressif ESP-IDF for the ESP32 (ESP32-WROOM-32, etc.) |
| [`install_esp32_rust_dev.sh`](./install_esp32_rust_dev.sh) | Rust `esp-rs` toolchain with `espup` and `cargo-espflash` |
| [`install_esp32_platformio_dev.sh`](./install_esp32_platformio_dev.sh) | PlatformIO + `espressif32` platform |

### STM32F4 Discovery

| Script | Purpose |
|--------|---------|
| [`install_stm32f4_discovery_rust_dev.sh`](./install_stm32f4_discovery_rust_dev.sh) | Rust embedded toolchain for the STM32F407VG (`thumbv7em-none-eabihf`) |
| [`install_stm32f4_discovery_platformio_dev.sh`](./install_stm32f4_discovery_platformio_dev.sh) | PlatformIO + `ststm32` platform for the `stm32f4discovery` board |

### micro:bit v2

| Script | Purpose |
|--------|---------|
| [`install_microbit_v2_rust_dev.sh`](./install_microbit_v2_rust_dev.sh) | Rust embedded toolchain for the Nordic nRF52833 (`thumbv7em-none-eabihf`) |
| [`install_microbit_v2_platformio_dev.sh`](./install_microbit_v2_platformio_dev.sh) | PlatformIO + `nordicnrf52` platform for the `bbcmicrobit_v2` board |

### Arduino Nano (ATmega328P)

| Script | Purpose |
|--------|---------|
| [`install_arduino_nano_rust_dev.sh`](./install_arduino_nano_rust_dev.sh) | Rust AVR toolchain for the Arduino Nano / Elegoo Nano 3.0 (`avr-atmega328p`) |
| [`install_arduino_nano_platformio_dev.sh`](./install_arduino_nano_platformio_dev.sh) | PlatformIO + `atmelavr` platform for the `nanoatmega328` board |

### Teensy 4.1

| Script | Purpose |
|--------|---------|
| [`install_teensy41_rust_dev.sh`](./install_teensy41_rust_dev.sh) | Rust toolchain for the Teensy 4.1 (`thumbv7em-none-eabihf`) with `teensy_loader_cli` |
| [`install_teensy41_platformio_dev.sh`](./install_teensy41_platformio_dev.sh) | PlatformIO + `teensy` platform for the `teensy41` board |

## Quick start

Clone the repository somewhere convenient (the scripts are self-contained):

```bash
git clone https://github.com/sfines/macos-embedded-toolchain-installers.git
cd macos-embedded-toolchain-installers
chmod +x install_*.sh
./install_<whatever>.sh
```

Most scripts add shell helpers (e.g. `get_idf`, `get_esp_rust`) to `~/.zshrc`, so after installation open a new terminal or run `source ~/.zshrc`.

## Usage notes

- These scripts are **idempotent-ish**: running them again will generally update existing installs or skip already-present components.
- The Rust scripts explicitly check for an existing Rust toolchain before installing through Homebrew, so they won't clobber a working `rustup` setup.
- Some installs (PlatformIO, `probe-rs-tools`, ESP-IDF tooling) can take several minutes because they download large toolchains or compile a lot of Rust code.
- The scripts include notes about USB-to-UART / ST-Link drivers where relevant.

## License

These scripts are provided as-is. Use, modify, and share them however you like.
