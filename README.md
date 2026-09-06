# Snake Assembly

A Snake game written in x86 16-bit assembly (NASM), running as a real MS-DOS
`.COM` executable.

It's played directly in the browser via
[js-dos](https://js-dos.com), which emulates DOS through DOSBox-X compiled to
WebAssembly.

## Project layout

- `asm/snake.asm` - the game source, assembled into a flat `.COM` binary.
- `dos/dosbox.conf` - DOSBox configuration used both for local testing and for
  the bundle shipped to the browser.
- `web/index.html` - loads js-dos and boots the DOS bundle.
- `build.sh` / `build.bat` - assembles the game and produces the browser bundle
  (Linux/macOS and Windows, respectively).
- `server.sh` / `server.bat` - serves `web/` over HTTP so the browser can load
  the bundle (Linux/macOS and Windows, respectively).

Everything works on Linux, macOS, and Windows, on both x86-64 and arm64 - the
scripts only shell out to standard, cross-architecture tools (NASM, zip,
Python, PowerShell), and check that each one is installed before using it.

## Requirements

- [NASM](https://www.nasm.us/)
  - macOS: `brew install nasm`
  - Linux: `sudo apt install nasm` / `sudo dnf install nasm` / `sudo pacman -S nasm`
  - Windows: `choco install nasm` / `scoop install nasm` / `winget install NASM.NASM`
- `zip` — Linux/macOS only, already available or installable via the same
  package managers as NASM. Windows uses PowerShell's `Compress-Archive`
  instead, which ships with the OS.
- Python (3.x) — used by `server.sh` / `server.bat` to serve files.
  - macOS: `brew install python`
  - Linux: `sudo apt install python3` / `sudo dnf install python3` / `sudo pacman -S python`
  - Windows: `winget install Python.Python.3` / `choco install python` / `scoop install python`

If a required tool is missing, the build/server scripts detect it and print
install instructions instead of failing with a cryptic error.

## Building

```bash
./build.sh      # Linux/macOS
build.bat       # Windows
```

This assembles `asm/snake.asm` into `build/snake.com`, copies it to
`dos/SNAKE.COM`, and packages `dos/SNAKE.COM` + `dos/dosbox.conf` into
`web/snake.jsdos` — the bundle js-dos loads in the browser.

Run this again any time you change `asm/snake.asm` or `dos/dosbox.conf`.

## Running

```bash
./server.sh     # Linux/macOS
server.bat      # Windows
```

Then open <http://localhost:8080> in a browser. DOS boots straight to the
`C:\>` prompt — type the following to start the game:

```bash
SNAKE
```

## Controls

- Arrow keys — move
- Esc — quit back to DOS
