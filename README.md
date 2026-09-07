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

## 🧰 Requirements

- [NASM](https://www.nasm.us/) - assembles `asm/snake.asm` into the `.COM` binary.
- `zip` - packages the DOS files into the `.jsdos` bundle (Linux/macOS only;
  Windows uses PowerShell's `Compress-Archive` instead).
- Python (3.x) - serves `web/` over HTTP via `server.sh` / `server.bat`.

## 🔨 Building

```bash
./build.sh      # Linux/macOS
build.bat       # Windows
```

This assembles `asm/snake.asm` into `build/snake.com`, copies it to
`dos/SNAKE.COM`, and packages `dos/SNAKE.COM` + `dos/dosbox.conf` into
`web/snake.jsdos` - the bundle js-dos loads in the browser.

Run this again any time you change `asm/snake.asm` or `dos/dosbox.conf`.

## 🌐 Running

```bash
./server.sh     # Linux/macOS
server.bat      # Windows
```

Then open <http://localhost:8080> in a browser.

## 💾 Starting the Game

DOS boots straight to the `C:\>` prompt - type the following to start the game:

```bash
SNAKE
```

## 🎮 Controls

| Key       | Action           |
|-----------|------------------|
| `↑` / `W` | Move snake up    |
| `↓` / `S` | Move snake down  |
| `←` / `A` | Move snake left  |
| `→` / `D` | Move snake right |
| `ESC`     | Quit back to DOS |

## 📁 Project Structure

```text
snake-asm/
├── .github/workflows/     # CI and GitHub Pages deploy workflows
├── asm/
│   └── snake.asm          # Game source code (NASM)
├── build/
│   └── snake.com          # Assembled flat binary (generated)
├── dos/
│   ├── dosbox.conf        # DOSBox configuration
│   └── SNAKE.COM          # DOS executable (generated)
├── web/
│   ├── index.html         # Loads js-dos and boots the bundle
│   └── snake.jsdos        # js-dos bundle (generated)
├── build.sh / build.bat   # Build scripts (Linux/macOS / Windows)
├── server.sh / server.bat # Local web server scripts (Linux/macOS / Windows)
├── LICENSE
└── README.md
```

## 🛠️ Technical Details

|              |                                                                                    |
| ------------ | ---------------------------------------------------------------------------------- |
| Language     | x86 16-bit Assembly (Real Mode)                                                    |
| Assembler    | NASM                                                                               |
| Platform     | MS-DOS, run in-browser via js-dos (DOSBox-X / WebAssembly)                         |
| File Format  | COM executable (flat binary, org 0x100)                                            |
| Binary size  | 182 bytes                                                                          |
| Video mode   | VGA Mode 13h (320x200, 256 colors), direct framebuffer writes at 0xA000            |
| Input        | BIOS keyboard interrupt (int 0x16), blocking - movement is turn-based per keypress |
| Dependencies | none - only BIOS/DOS interrupts (int 0x10, int 0x16, int 0x21)                     |
| Exit         | restores text mode and returns to DOS via int 0x21, ah=0x4C                        |
