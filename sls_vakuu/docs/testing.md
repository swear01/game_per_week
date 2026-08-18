# VakuuPlayer 測試手冊

> 目前只在使用者離開遊戲後執行部署與重啟；開發期間可安全地只執行 build。

## 快速迭代循環

```bash
./test.sh   # build → 部署到 MacOS/mods/VakuuPlayer → 重啟遊戲
```

只有使用者確認目前遊戲 instance 已結束後才執行 `./test.sh`。

## 驗證清單

1. **初始化**：`~/Library/Application Support/SlayTheSpire2/logs/godot.log` 搜尋 `VakuuPlayer`
   - 期望：`Loading assembly DLL` → `Calling initializer` → `Finished mod initialization`
   - 無 Harmony exception、無本地化 key exception
2. **角色頁**：五個原生角色名稱、角色頁與外觀保持原樣
3. **第一幕開局**：
   - 角色原生起始遺物為空
   - 顯示 Vakuu Ancient，不顯示 Neow
   - 首次對話有四句瓦庫台詞
   - 只有一個「接受」選項
4. **遺物發放**：按下接受後取得全部 10 件，包含 Vakuu Contract 與所有負面效果
5. **Preserved Fog**：顯示原生手動選牌畫面，選 3 張牌刪除並加入 Folly；不可隨機刪牌
6. **第一場戰鬥**：Vakuu Contract 每回合從左到右自動出牌，最多 13 張，結束後控制權回到玩家
7. **第三幕**：新局的第三幕 Ancient 池不包含 Vakuu
8. **回歸**：五個角色、存檔載入、無 Preserved Fog 的路徑、遺物圖鑑與 hover UI

## 日誌與錯誤

- 主 log：`~/Library/Application Support/SlayTheSpire2/logs/godot.log`
- mod log：`FileLog.Log(...)`
- 遺物 callback 例外必須可見；不可隨機補發、隨機刪牌或靜默 fallback

## 禁止事項

- 不在使用者遊玩期間替換 DLL、啟動或重啟遊戲
- 不直接呼叫 `NGame.StartNewSingleplayerRun` 建立測試局
- 正式 mod 不保留 harness
- 不使用 `CardSelectCmd.UseSelector` 自動選擇 Preserved Fog 刪牌
