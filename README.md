# game_per_week

一週一遊戲／週更原型相關專案集合（單一 repo、多子專案）。

## 子專案

| 資料夾 | 說明 |
|--------|------|
| `街頭卡牌小混混` | Unity 6（6000.3.x）卡牌對戰原型 |
| `deck_merger` | Python：牌組／牌池合併與相關工具 |
| `diy_minecraft_mods` | Minecraft：NeoForge Gradle mod（`Karst_terrian`）、resource packs、相關 skills |

各子資料夾內有各自的 `.gitignore`（Unity／Python／Gradle 等）。

## 本機開發簡註

- **Unity 專案**：用 Unity Hub 開啟 `街頭卡牌小混混` 目錄即可。
- **deck_merger**：進入 `deck_merger` 後依該目錄的 `README.md` 建立 venv 與安裝依賴。
- **diy_minecraft_mods**：Mod 主專案在 `diy_minecraft_mods/Karst_terrian`（NeoForge／Gradle），依該目錄 `README.md` 開發。
