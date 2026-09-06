#!/bin/bash

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_DIR="$ROOT_DIR/web"
PORT=8080

if command -v python3 >/dev/null 2>&1; then
    PYTHON=python3
elif command -v python >/dev/null 2>&1; then
    PYTHON=python
else
    echo "Error: Python is not installed."
    echo "Install it with:"
    echo
    case "$(uname -s)" in
        Darwin)
            echo "    brew install python"
            ;;
        Linux)
            echo "    sudo apt install python3   # Debian/Ubuntu"
            echo "    sudo dnf install python3   # Fedora"
            echo "    sudo pacman -S python       # Arch"
            ;;
        *)
            echo "    See https://www.python.org/downloads/"
            ;;
    esac
    echo
    exit 1
fi

cd "$WEB_DIR"

echo "Serving $WEB_DIR at http://localhost:$PORT"

"$PYTHON" -m http.server "$PORT"
