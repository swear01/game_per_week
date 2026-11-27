#!/bin/sh
set -eu
game_dir="$(cd "$(dirname "$0")/game" && pwd)"
if command -v godot >/dev/null 2>&1; then
    exec godot --path "$game_dir"
fi
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$game_dir"
