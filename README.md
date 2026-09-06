# Snake Assembly 🐍

[![CI](https://github.com/madureira/snake-asm/actions/workflows/ci.yml/badge.svg)](https://github.com/madureira/snake-asm/actions/workflows/ci.yml)
![Assembly](https://img.shields.io/badge/assembly-x86--16--bit%20(NASM)-blue)
![Platform](https://img.shields.io/badge/platform-MS--DOS%20%7C%20WebAssembly-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)

A Snake game written in x86 16-bit assembly (NASM), running as a real MS-DOS
`.COM` executable.

It's played directly in the browser via
[js-dos](https://js-dos.com), which emulates DOS through DOSBox-X compiled to
WebAssembly.

[![Live Demo](.github/live_demo_badge.svg)](https://madureira.github.io/snake-asm)

## Requirements

- [NASM](https://www.nasm.us/)
  - macOS: `brew install nasm`
  - Linux: `sudo apt install nasm` / `sudo dnf install nasm` / `sudo pacman -S nasm`
  - Windows: `choco install nasm` / `scoop install nasm` / `winget install NASM.NASM`
- `zip` - Linux/macOS only, already available or installable via the same
  package managers as NASM. Windows uses PowerShell's `Compress-Archive`
  instead, which ships with the OS.
- Python (3.x) - used by `server.sh` / `server.bat` to serve files.
  - macOS: `brew install python`
  - Linux: `sudo apt install python3` / `sudo dnf install python3` / `sudo pacman -S python`
  - Windows: `winget install Python.Python.3` / `choco install python` / `scoop install python`

## Building

```bash
./build.sh      # Linux/macOS
build.bat       # Windows
```

This assembles `asm/snake.asm` into `build/snake.com`, copies it to
`dos/SNAKE.COM`, and packages `dos/SNAKE.COM` + `dos/dosbox.conf` into
`web/snake.jsdos` - the bundle js-dos loads in the browser.

Run this again any time you change `asm/snake.asm` or `dos/dosbox.conf`.

## Running

```bash
./server.sh     # Linux/macOS
server.bat      # Windows
```

Then open <http://localhost:8080> in a browser.

## Starting the Game

💾 DOS boots straight to the `C:\>` prompt - type the following to start the game:

```bash
SNAKE
```

## Controls

| Key        | Action            |
| ---------- | ----------------- |
| Up arrow   | Move up           |
| Down arrow | Move down         |
| Left arrow | Move left         |
| Right arrow| Move right        |
| Esc        | Quit back to DOS  |
