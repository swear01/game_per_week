# game_per_week

一週一遊戲／週更原型相關專案集合（單一 repo、多子專案）。

## 統一驗證

```bash
make test
```

這會使用 `uv` 執行 `deck_merger` 的 pytest 測試，以及執行 `tests/jupyter/` 的 Python 單元測試；需要遊戲與 Steam 的實機整合測試仍依 `sls_vakuu/docs/testing.md` 操作。

## 子專案

| 資料夾 | 說明 |
|--------|------|
| `街頭卡牌小混混` | Unity 6（6000.3.x）卡牌對戰原型 |
| `deck_merger` | Python：牌組／牌池合併與相關工具 |

**Minecraft 自製 mod／資源包**已獨立為 [swear01/diy_minecraft_mods](https://github.com/swear01/diy_minecraft_mods)（本 repo 不再包含該目錄）。

各子資料夾內有各自的 `.gitignore`（Unity／Python）。

## 本機開發簡註

- **Unity 專案**：用 Unity Hub 開啟 `街頭卡牌小混混` 目錄即可。
- **deck_merger**：進入 `deck_merger` 後依該目錄的 `README.md` 建立 venv 與安裝依賴。
