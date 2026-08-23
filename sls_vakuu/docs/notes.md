# Notes

> Tacit knowledge an agent can't infer from reading code.

## Gotchas
- **EA 版本漂移**: STS2 每 1–2 週更新，API 簽名常變。寫任何 patch 前先讀 `release_info.json` + `sts2.runtimeconfig.json` + 反編譯 `sts2.dll` 核對，不要憑記憶
- **skillshare project config 是陣列**: targets 用 `- name: xxx` 列表格式；照抄 global config 的 map 格式會報 `cannot unmarshal !!map`（已踩過，方案已棄用）
- **manifest 陷阱**: `<game>/mods/` 下所有 `.json` 都被當候選 manifest，別在 mods 樹裡放設定檔；manifest id = dll/pck 檔名基底
- **`affects_gameplay`**: 純外觀 mod 設 `false`，否則聯機會 desync；設錯會被檢查
- **不用 NuGet 版 Harmony/GodotSharp**: 必須引用遊戲目錄內的同版副本，版本混用能編過但運行時掛
- **pool 註冊時機**: `ModHelper.AddModelToPool` 必須在池凍結前，之後丟異常

## Verified gotchas
- **Accessibility 授權要查對 executable**：`AXIsProcessTrusted()` 只回報目前呼叫者；從 agent shell 開的 Swift helper 回 `false`，不能推論 launchd 的 `/Users/swear/.local/bin/hapi`。2026-08-18 查 system TCC DB 確認 hapi 的 `kTCCServiceAccessibility` `auth_value=2`。本次測試真正的阻礙是 STS2 `settings.save` 將 local/Workshop `VakuuPlayer` 的 `is_enabled` 都設成 `false`，不是 hapi 權限。
- **STS2 開局時 NRun 尚未建立**：`NGame.StartRun` 的順序是 preload → `RunManager.FinalizeStartingRelics()` → `RunManager.Launch()` → `NRun.Create(runState)`。因此在 Preserved Fog 的 `AfterObtained` 中強制 `ShouldSelectLocalCard=true` 會讓 `CardSelectCmd.FromDeckGeneric` 取用尚未存在的 `NOverlayStack.Instance`，產生 NRE；單獨 patch 選擇判斷不足以建立開局 UI。
- **較小的正確延後點**：`RunManager.EnterAct` 在 `NRun.Create` 後完成第一個 map/room 初始化、觸發 `ActEntered`、淡入，再 await `Hook.AfterActEntered(runState)`；該 hook 逐一 await relic 的 `AfterActEntered()`。因此可讓 `VakuuContract.AfterActEntered()` 執行暫存的 Preserved Fog 選牌，避免重寫 `NGame` 開局流程或 patch async state machine。
- **Preserved Fog 必須保存牌組 snapshot**：目前 Vakuu 遺物取得順序中 Preserved Fog 後面還有 SereTalon、DistinguishedCape，它們會新增詛咒/Apparitions。延後選牌若直接使用當時牌組，會讓後加入的牌變成可選；協調器必須在 `AfterObtained` 保存可移除卡片，之後用 `CardSelectCmd.FromDeckGeneric` 的 filter 限制候選。實機 log 已確認即使 VakuuContract 在取得順序最後，Preserved Fog 執行時 owner.Relics 已包含它。
- **不要清空角色原生 `StartingRelics`**：早期版本從 getter 直接注入 Vakuu 遺物，改成第一幕 Ancient callback 發放後仍留下清空 getter 的 patch，導致五個職業的新局遺物都被覆蓋。原生起始遺物與事件發放的 10 件 Vakuu 遺物不衝突；移除 getter patch 即可同時保留兩者。
- **實機 runner 要還原「原本不存在」的檔案**：只複製 `progress.save` 不足以保護 profile，因為測試會建立 `current_run.save`，Steam Cloud 也可能在遊戲退出時同步它。runner 現在備份帳號的 settings、一般／modded profile 與完整 `profile1` 目錄，cleanup 先移除測試後狀態再還原 snapshot；真實 profile 仍須在測試前後用 SHA-256 guard 查驗 RemoteStorage，不能只看本機 cleanup。
- **Harness 必須在 Accept task 等待期間處理 Preserved Fog**：事件取得 Preserved Fog 時 `NRun` 已存在，原生 `AfterObtained` 會同步等待卡牌選擇；若 frame loop 先因 `_optionTask` 未完成而 return，就永遠走不到選牌程式。選牌 screen 的處理必須排在 event task 等待之前。
- **Vakuu 實機回歸要隔離其他模組，開局呼叫也要原子防重入**：2026-08-24 在未停用其他模組時，`UnifiedSavePath`、`QuickSlAndRerollStart` 初始化失敗，`QuickAnimationMode` 也介入開局。runner 測試期間只啟用本機 VakuuPlayer／VakuuHarness，cleanup 再由 settings snapshot 還原原模組清單；Harness 另以 `Interlocked.Exchange` 保證 `BeginRunLocally` 只呼叫一次，避免 frame callback 重入。
- **實機截圖直接取 Godot viewport**：macOS 的 WindowServer window id 與 `screencapture -l` 對這個遊戲不可靠；Harness 用 `tree.Root.GetTexture().GetImage().SavePng(...)` 取得原生畫面，再由 runner 依 log 路徑收集，無需 Accessibility 或 Screen Recording helper。
- **STS2 語言與 LocTable 契約**：v0.111.0 的遊戲語言碼是三字母 `eng`/`zhs`/`zht` 等；`LocTable.MergeWith` 會直接寫入底層 dictionary，因此可插入原本不存在的 `VAKUU_CONTRACT.*` keys。未知語言目前明確記錄 English fallback。
- **Choices Paradox 的戰鬥選牌不是 NDeckCardSelectScreen**：`AfterPlayerTurnStart` 透過 `CardSelectCmd.FromSimpleGrid` 建立 `NSimpleCardSelectScreen`；測試 harness 必須反射正確的 screen type，否則會卡在自動出牌前。
- **每回合接管已實機驗證**：正常模組環境下記錄到 auto phase turn 1、2，且自動出牌 turn 1、2；第一回合後 `PlayerCmd.EndTurn` 成功送出，控制權回歸條件成立。
- **Harness 的 `CardCmd.AutoPlay` postfix 只觀察 Task 建立**：它不代表整個牌效應或 `Hook.AfterAutoPrePlayPhaseEntered` 已完成；測試若過早送出 EndTurn／win，會留下 choice-context stack 錯誤。需要等待完整 hook，或以手動實機結果判定控制權回歸。
- **測試關閉遊戲不可用 `pkill`／`SIGKILL`**：2026-08-20 發現每次 Jupyter／`test.sh` 重啟使用程序終止後，macOS 會顯示「Slay the Spire 2 未預期關閉」。正式關閉流程改用 AppKit `NSRunningApplication.terminate()` 對遊戲 PID 發出正常退出請求，等待 30 秒，最多重試同一請求一次；逾時只報錯、不強制殺程序。
- **macOS 遊戲程序路徑要匹配實際 bundle**：`ps` 顯示的可執行檔路徑是 `/Slay the Spire 2/SlayTheSpire2.app/Contents/MacOS/Slay the Spire 2`；PID 過濾與退出 helper 都以完整 executable suffix 做 exact match，不能誤寫成 `/Slay the Spire 2.app/` 或只做目錄 substring match。
- **Steam Workshop 描述支援分語言 metadata**：2026-08-20 查閱官方 `ISteamUGC` 文件並用 Workshop 3784362897 實測；`SetItemUpdateLanguage` 先於 `SetItemTitle`／`SetItemDescription`，可分別寫入 `english`、`schinese`、`tchinese`。官方 ModUploader 的 `workshop.json` 目前只有單一描述欄位，不能直接表達翻譯；正式描述不可把三種語言拼在一起，應使用 Workshop 語言欄位或支援該 API 的上傳器。
- **Workshop 個人連結不屬於 `workshop.json`**：2026-08-21 從本機同步的個人資料檔讀取 Facebook、X/Twitter、YouTube、Reddit 帳號，並以已登入的 Workshop「編輯連結」頁面寫入 3784362897；官方 UGC uploader 不會更新這個區塊，描述欄位因此不再放 URL。
- **Workshop 圖片 payload 契約**：官方 ModUploader 的 `image.png` 是主圖，`previews/` 是以檔名維護的附加圖；本地缺少舊檔名會在更新時移除遠端圖片。2026-08-22 已用 Steam F12 截圖建立四張附加圖，並以 512×512 宣傳主圖替換舊 v0.1.0 主圖。
- **本機 .NET PATH**：SDK 位於 `$HOME/.dotnet/dotnet`；`test.sh` 會先加入 `$HOME/.dotnet`，手動執行 build 也要先設定同一個 PATH。

## Decisions
- **2026-08-16 不使用 skillshare 項目級 agent（`.skillshare/agents/`）**：使用者有既有的 agent sync 體系 — repo 級指令寫 `AGENTS.md`（agents_rule 工具管理，已註冊 `~/.agents/managed-repos.txt`），全局 agent 指令走 `~/.agents/AGENTS.md`（`transfer_MAC/scripts/sync-ai-agent-configs.py render` 分發到 codex/claude/gemini/opencode）。不要再自創 agent 文件。
- **STS2 技術知識集中在 `RESEARCH.md` 單一文件**：避免 docs/ 與 RESEARCH.md 雙頭管理；docs/ 只記項目狀態
