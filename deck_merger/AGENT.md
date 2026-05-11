# AGENT.md

給在此 repo 改程式的助理：**規則以 `doc/企劃書.md` 為準**；目錄與模組分工見 **`doc/專案架構.md`**；安裝與 CLI 見 **`README.md`**。

## 原則

- **實作對齊企劃書**：行為與範圍須與 `doc/企劃書.md` 一致；若實作與企劃書不符，**應修改程式或企劃書其中一方**（或兩者一併調整）以消除落差，勿讓程式與文件長期各說各話。
- **單一路徑**：玩家／`--agent`／LLM 的文字指令都經 **`ui_commands.parse_player_line`**，不要在各 UI 重複解析。
- **改動範圍**：對齊任務即可，避免無關重構；行為變更後跑 **`pytest tests/ -v`**。
- **機密**：API key 只放 **`.env`**，勿寫進 knowhow 或版控檔案。
- **計畫檔**：使用者未要求時勿改 `.cursor/plans/` 等 plan 檔。

## 技術底線

- Python **3.14+**；套件 **`deck_merger`**，程式在 **`src/`**。
- 更細的模組表、資料流圖： **`doc/專案架構.md`**。

## 常用指令

```bash
pip install -e ".[dev]"
pytest tests/ -v
```
