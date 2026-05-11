from pathlib import Path

import pytest

from deck_merger import knowhow as kh


def test_validate_knowhow_version_rejects_traversal():
    with pytest.raises(ValueError):
        kh.validate_knowhow_version("../x")
    with pytest.raises(ValueError):
        kh.validate_knowhow_version("a/b")


def test_knowhow_subdir_must_be_under_knowhow(tmp_path: Path):
    root = tmp_path / "repo"
    (root / "knowhow" / "0.9.0").mkdir(parents=True)
    p = kh.knowhow_subdir(root, "0.9.0")
    assert p.name == "0.9.0"
    assert p.parent.name == "knowhow"


def test_load_knowhow_text_truncates(tmp_path: Path):
    root = tmp_path / "repo"
    d = root / "knowhow" / "1.0.0"
    d.mkdir(parents=True)
    (d / "a.md").write_text("x" * 100, encoding="utf-8")
    text = kh.load_knowhow_text(root, "1.0.0", max_chars=50)
    assert "truncated" in text or len(text) <= 60


def test_append_session_notes(tmp_path: Path):
    root = tmp_path / "repo"
    kh.append_session_notes(root, "1.0.0", "line1\n")
    p = root / "knowhow" / "1.0.0" / "session_notes.md"
    assert p.read_text(encoding="utf-8").endswith("line1\n")


def test_resolved_rules_version_env(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("DECK_MERGER_KNOWHOW_VERSION", "9.9.9")
    assert kh.resolved_rules_version() == "9.9.9"
    monkeypatch.delenv("DECK_MERGER_KNOWHOW_VERSION", raising=False)


def test_resolved_rules_version_package(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.delenv("DECK_MERGER_KNOWHOW_VERSION", raising=False)
    from deck_merger import __version__

    assert kh.resolved_rules_version() == __version__
