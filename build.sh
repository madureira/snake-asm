#!/bin/bash

set -e

# Project directories
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASM_DIR="$ROOT_DIR/asm"
BUILD_DIR="$ROOT_DIR/build"
DOS_DIR="$ROOT_DIR/dos"
WEB_DIR="$ROOT_DIR/web"

# Output files
COM_FILE="$BUILD_DIR/snake.com"
DOS_COM_FILE="$DOS_DIR/SNAKE.COM"
JSDOS_FILE="$WEB_DIR/snake.jsdos"

echo "========================================"
echo " Building Snake"
echo "========================================"

OS_NAME="$(uname -s)"

# Check NASM
if ! command -v nasm >/dev/null 2>&1; then
    echo "Error: NASM is not installed."
    echo "Install it with:"
    echo
    case "$OS_NAME" in
        Darwin)
            echo "    brew install nasm"
            ;;
        Linux)
            echo "    sudo apt install nasm   # Debian/Ubuntu"
            echo "    sudo dnf install nasm   # Fedora"
            echo "    sudo pacman -S nasm     # Arch"
            ;;
        *)
            echo "    See https://www.nasm.us/"
            ;;
    esac
    echo
    exit 1
fi

# Check ZIP
if ! command -v zip >/dev/null 2>&1; then
    echo "Error: zip is not installed."
    echo "Install it with:"
    echo
    case "$OS_NAME" in
        Darwin)
            echo "    brew install zip"
            ;;
        Linux)
            echo "    sudo apt install zip   # Debian/Ubuntu"
            echo "    sudo dnf install zip   # Fedora"
            echo "    sudo pacman -S zip     # Arch"
            ;;
        *)
            echo "    See https://infozip.sourceforge.net/Zip.html"
            ;;
    esac
    echo
    exit 1
fi

# Create directories
mkdir -p "$BUILD_DIR"
mkdir -p "$DOS_DIR"
mkdir -p "$WEB_DIR"

echo
echo "[1/4] Assembling snake.asm..."

nasm \
    -f bin \
    "$ASM_DIR/snake.asm" \
    -o "$COM_FILE"

echo "      Created: $COM_FILE"

echo
echo "[2/4] Copying DOS executable..."

cp "$COM_FILE" "$DOS_COM_FILE"

echo "      Created: $DOS_COM_FILE"

echo
echo "[3/4] Creating js-dos bundle..."

TEMP_DIR="$(mktemp -d)"

# js-dos configuration
mkdir -p "$TEMP_DIR/.jsdos"

cp "$DOS_DIR/dosbox.conf" \
   "$TEMP_DIR/.jsdos/dosbox.conf"

# IMPORTANT:
# The DOS executable must be at the root
# of the js-dos bundle.
cp "$DOS_COM_FILE" \
   "$TEMP_DIR/SNAKE.COM"

(
    cd "$TEMP_DIR"

    zip -q -r \
        "$JSDOS_FILE" \
        .jsdos \
        SNAKE.COM
)

rm -rf "$TEMP_DIR"

echo "      Created: $JSDOS_FILE"

echo
echo "[4/4] Verifying bundle..."

if command -v unzip >/dev/null 2>&1; then
    unzip -l "$JSDOS_FILE"
else
    echo "      (skipped: unzip not installed)"
fi

echo
echo "========================================"
echo " Build complete."
echo "========================================"

echo
echo "Files:"

ls -lh \
    "$COM_FILE" \
    "$DOS_COM_FILE" \
    "$JSDOS_FILE"

echo
echo "Run the web server with:"
echo
echo "    ./server.sh"
echo
echo "Then open:"
echo
echo "    http://localhost:8080"
echo
