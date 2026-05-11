"""未執行 pip install -e . 時，讓 pytest 仍能以 deck_merger 套件名載入 src/ 內模組。"""

import importlib.util
import sys
from pathlib import Path

_root = Path(__file__).resolve().parents[1]
_src = _root / "src"

if _src.is_dir() and "deck_merger" not in sys.modules:
    _init = _src / "__init__.py"
    spec = importlib.util.spec_from_file_location(
        "deck_merger",
        _init,
        submodule_search_locations=[str(_src)],
    )
    if spec and spec.loader:
        _pkg = importlib.util.module_from_spec(spec)
        sys.modules["deck_merger"] = _pkg
        spec.loader.exec_module(_pkg)
