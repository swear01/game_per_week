#!/usr/bin/env python3
"""Generate one Minecraft OGG sound effect with ElevenLabs."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path


API_URL = "https://api.elevenlabs.io/v1/sound-generation"


def post_sound(text: str, duration: float | None, prompt_influence: float | None) -> bytes:
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        raise SystemExit("ELEVENLABS_API_KEY is required.")
    payload: dict[str, object] = {"text": text}
    if duration is not None:
        payload["duration_seconds"] = duration
    if prompt_influence is not None:
        payload["prompt_influence"] = prompt_influence
    request = urllib.request.Request(
        API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"ElevenLabs sound generation failed: HTTP {exc.code}: {detail}") from exc


def convert_mp3_to_ogg(mp3: Path, ogg: Path) -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("ffmpeg is required to convert ElevenLabs MP3 output to Minecraft OGG.")
    ogg.parent.mkdir(parents=True, exist_ok=True)
    encoders = subprocess.run([ffmpeg, "-hide_banner", "-encoders"], check=False, capture_output=True, text=True).stdout
    if "libvorbis" in encoders:
        cmd = [ffmpeg, "-y", "-i", str(mp3), "-vn", "-c:a", "libvorbis", "-q:a", "4", str(ogg)]
    else:
        cmd = [ffmpeg, "-y", "-i", str(mp3), "-vn", "-ac", "2", "-c:a", "vorbis", "-strict", "-2", "-q:a", "4", str(ogg)]
    subprocess.run(cmd, check=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--text", required=True)
    parser.add_argument("--output", required=True, help="Output .ogg path.")
    parser.add_argument("--duration-seconds", type=float)
    parser.add_argument("--prompt-influence", type=float)
    parser.add_argument("--keep-mp3", help="Optional debug MP3 path.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output = Path(args.output).expanduser().resolve()
    audio = post_sound(args.text, args.duration_seconds, args.prompt_influence)
    if args.keep_mp3:
        mp3 = Path(args.keep_mp3).expanduser().resolve()
        mp3.parent.mkdir(parents=True, exist_ok=True)
        mp3.write_bytes(audio)
    else:
        temp = tempfile.NamedTemporaryFile(suffix=".mp3", delete=False)
        mp3 = Path(temp.name)
        temp.close()
        mp3.write_bytes(audio)
    convert_mp3_to_ogg(mp3, output)
    if not args.keep_mp3:
        mp3.unlink(missing_ok=True)
    print(json.dumps({"ogg": str(output), "bytes": output.stat().st_size}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
