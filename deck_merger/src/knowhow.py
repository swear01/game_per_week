"""Version-scoped Markdown know-how under repo ``knowhow/<version>/``."""

from __future__ import annotations

import os
from pathlib import Path

_DEFAULT_MAX_CHARS = 12000
_MAX_APPEND_BYTES = 8192


def validate_knowhow_version(v: str) -> str:
    v = v.strip()
    if not v:
        raise ValueError("empty knowhow version")
    if ".." in v or "/" in v or "\\" in v:
        raise ValueError(f"invalid knowhow version: {v!r}")
    return v


def knowhow_subdir(repo_root: Path, version: str) -> Path:
    version = validate_knowhow_version(version)
    root = repo_root.resolve()
    sub = (root / "knowhow" / version).resolve()
    sub.relative_to(root / "knowhow")
    return sub


def resolved_rules_version() -> str:
    env = os.environ.get("DECK_MERGER_KNOWHOW_VERSION", "").strip()
    if env:
        return validate_knowhow_version(env)
    from deck_merger import __version__

    return validate_knowhow_version(__version__)


def load_knowhow_text(
    repo_root: Path,
    version: str,
    *,
    max_chars: int | None = None,
) -> str:
    max_c = max_chars
    if max_c is None:
        raw = os.environ.get("DECK_MERGER_KNOWHOW_MAX_CHARS", "").strip()
        max_c = int(raw) if raw.isdigit() else _DEFAULT_MAX_CHARS
    sub = knowhow_subdir(repo_root, version)
    if not sub.is_dir():
        return ""
    paths = sorted(sub.rglob("*.md"))
    chunks: list[str] = []
    total = 0
    for p in paths:
        rel = p.relative_to(sub)
        try:
            text = p.read_text(encoding="utf-8")
        except OSError:
            continue
        block = f"### knowhow file: {rel.as_posix()}\n\n{text}\n\n"
        if total + len(block) > max_c:
            rest = max_c - total
            if rest > 0:
                chunks.append(block[:rest] + "\n... [truncated]\n")
            break
        chunks.append(block)
        total += len(block)
    return "".join(chunks).strip()


def append_session_notes(
    repo_root: Path,
    version: str,
    text: str,
    *,
    max_append_bytes: int = _MAX_APPEND_BYTES,
) -> Path:
    raw = text.encode("utf-8")
    if len(raw) > max_append_bytes:
        raw = raw[:max_append_bytes]
        text = raw.decode("utf-8", errors="ignore")
    sub = knowhow_subdir(repo_root, version)
    sub.mkdir(parents=True, exist_ok=True)
    path = sub / "session_notes.md"
    with path.open("a", encoding="utf-8") as f:
        f.write(text)
        if not text.endswith("\n"):
            f.write("\n")
    return path
