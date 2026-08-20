#!/usr/bin/env bash
# VakuuPlayer 一鍵測試：build → 部署到本地 mods → 重啟遊戲
# 本地 mods 目錄（macOS）：SlayTheSpire2.app/Contents/MacOS/mods/
set -euo pipefail
cd "$(dirname "$0")"

export PATH="$HOME/.dotnet:$PATH"
GAME=~/Library/Application\ Support/Steam/steamapps/common/"Slay the Spire 2"
MODS="$GAME/SlayTheSpire2.app/Contents/MacOS/mods/VakuuPlayer"

echo "== build =="
dotnet build -c Release src/VakuuPlayer/VakuuPlayer.csproj

echo "== stop existing game gracefully =="
python3 ../tests/jupyter/quit_game.py

echo "== deploy =="
mkdir -p "$MODS"
cp src/VakuuPlayer/bin/Release/net9.0/VakuuPlayer.dll "$MODS/"
cp deploy/VakuuPlayer/content/VakuuPlayer.json "$MODS/"

echo "== restart game =="
open "steam://rungameid/2868840"
echo "deployed to $MODS"
