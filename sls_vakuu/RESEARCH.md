# Slay the Spire 2 Mod 开发研究笔记

> 研究日期：2026-08-16 · 本机游戏版本：**v0.111.0** (commit 41cef1ea) · macOS arm64

## 1. 结论速览

STS2 (EA) 自带官方 mod 加载器，mod 是 **C# (net9.0) DLL + 可选 Godot .pck 资源包**，通过一个 JSON manifest 声明。
核心工作流：写 C# → 引用游戏自带 DLL → 编译 → 复制到 `<游戏>/mods/<ModId>/` → 启动游戏加载。

## 2. 技术栈（以游戏为准，不是 NuGet）

- **目标框架**: `net9.0`，游戏自带 .NET runtime 9.0.7（读 `sts2.runtimeconfig.json` 确认）
- **引用三个游戏自带程序集**（同一安装目录，`Private=false` 不要拷进 mod）:
  - `sts2.dll` — 所有模型、命令、hook、加载器类型（用 ILSpy 反编译它写代码）
  - `0Harmony.dll` — Harmony 补丁运行时（游戏自己就在用）
  - `GodotSharp.dll` — Godot C# API
- **Godot 4.5.x .NET 版**：仅做图片/UI/本地化等 .pck 资源时才需要
- 本机路径：`~/Library/Application Support/Steam/steamapps/common/Slay the Spire 2/SlayTheSpire2.app/Contents/Resources/data_sts2_macos_arm64/`

⚠️ EA 更新频繁（每月主分支 + 每两周 beta），签名会变，维护时需重新反编译核对。

## 3. Mod 结构与 manifest

```
<STS2>/mods/FieldNotes/
  FieldNotes.json   ← manifest（必填）
  FieldNotes.dll    ← C# 代码（has_dll: true 时）
  FieldNotes.pck    ← Godot 资源（has_pck: true 时）
```

```json
{
  "id": "FieldNotes",
  "name": "Field Notes",
  "author": "me",
  "description": "...",
  "version": "0.1.0",
  "has_pck": true,
  "has_dll": true,
  "min_game_version": "0.111.0",
  "dependencies": [{"id": "BaseLib", "min_version": "3.1.2"}],
  "affects_gameplay": true
}
```

要点：
- manifest 文件名 = mod id；dll/pck 与 id 同名，放在同一目录
- `affects_gameplay: false` 的纯外观 mod 联机时不做校验（设错会 desync）
- `mods/` 下递归扫描，任何 `.json` 都可能被当 manifest，别乱放配置文件
- 依赖通过 `dependencies` 声明，需先加载

## 4. 代码入口与集成方式（从侵入小到大）

```csharp
using HarmonyLib;
using MegaCrit.Sts2.Core.Modding;

[ModInitializer(nameof(Initialize))]
public static class ModEntry
{
    public static void Initialize()
    {
        ModHelper.AddModelToPool<ColorlessCardPool, FieldNotesCard>();
        new Harmony("example.fieldnotes").PatchAll(typeof(ModEntry).Assembly);
    }
}
```

1. **实现模型方法 / 用命令 API**（首选）：自定义卡牌实现 `OnPlay`，用 `CreatureCmd`/`CardPileCmd` 等游戏命令，别直接改状态
2. **语义 Hook**：`MegaCrit.Sts2.Core.Hooks.Hook` 提供战斗/回合/卡牌/奖励/药水/伤害/格挡等生命周期钩子
3. **Harmony 补丁**（最后手段）：精确指定类型+方法+参数签名，别 PatchAll 同名重载

内容注册用 `ModHelper.AddModelToPool<池类型, 模型类>()`，必须在池冻结前调用。

## 5. 可做内容类型

卡牌、药水、遗物、能力(Powers)、地图事件、Ancient 遭遇 —— 社区框架 **ModSmith** 对以上全部开箱即用；
BaseLib 提供更多配置/内容 API 和 mod 间冲突协调框架。

## 6. 工具链

| 工具 | 用途 | 本机状态 |
| --- | --- | --- |
| .NET 9 SDK | 编译 | ❌ 未安装（需 brew install dotnet-sdk） |
| C# 编辑器 / IDE | 写代码 | — |
| ILSpy | 反编译 sts2.dll 查 API | 未装 |
| Godot 4.5.x .NET | 做 .pck 资源 | 未装（做纯代码 mod 可跳过） |
| ModUploader | 官方 Workshop 上传器（osx-arm64 zip 现成） | ❌ 未下载 |
| Steam Workshop | 已订阅 BaseLib + 20+ mod | ✅ 现成测试环境 |

## 7. 模板与参考

- **Alchyr/ModTemplate-StS2** — 官方社区模板（空 mod / content / character 三种，含 BaseLib 依赖）
- **Alchyr/BaseLib-StS2** — 社区基础库（已订阅），文档 alchyr.github.io/BaseLib-Wiki
- **ModSmith (cpimhoff/Sts2-ModSmith)** — 更高层框架，内置注册系统和工具
- **fresh-milkshake/Modding-Tutorial** — 版本感知的完整教程（环境→加载→反编译→hook→pck→打包），含自定义卡/药水/遗物/事件/GUI 章节
- **STS2 Modding MCP (elliotttate/sts2-modding-mcp)** — AI 辅助：151 个工具，可反编译游戏源码、构建、部署、自动试玩（适合配合本 agent 工作流）
- **megacrit/sts2-mod-uploader** — 官方 Workshop 上传器

## 8. 推荐开发流程

1. `brew install dotnet-sdk`（或 dotnet-sdk-9.0）
2. 建 net9.0 classlib 项目，csproj 引用游戏三件套，`GameDir`/`Sts2DataDir` 用 MSBuild 属性传入
3. 用 ILSpy / Modding MCP 查 sts2.dll 里要 hook 的类和方法
4. 写 ModEntry + 内容模型 + 本地化 json + 资源（可选）
5. `dotnet build` → 拷贝 `mods/<ModId>/` 到游戏目录 → 启动游戏看日志调试
6. 稳定后按 manifest 规范更新版本号，Workshop 上传

## 9. 发布到 Steam Workshop（官方上传器）

官方工具：**megacrit/sts2-mod-uploader**（最新 v0.2.0，本机可用 `ModUploader-osx-arm64.zip`，Steam 客户端需在运行）。Workshop 支持自 v0.107.1 起正式启用。

### 首次上传
1. 运行 ModUploader → 生成 `NewModWorkspace/`
2. 改名（如 `MyMod/`），mod 文件放入其中 `content/` 目录（至少 json，一般 dll + pck）
3. 填 `workshop.json`，替换 `image.png`（**必须 < 1MB**），可选 `previews/` 额外图
4. 在 ModUploader 所在目录运行：`ModUploader upload -w <workspace文件夹>`

### 更新
1. 新文件放入 `content/`，`workshop.json` 里填 `changeNote`
2. 重跑 `ModUploader upload -w <workspace文件夹>` — mod id 自动从 `mod_id.txt` 读取

### workshop.json 字段
| 字段 | 说明 |
| --- | --- |
| `title` / `description` | 标题 / 描述 |
| `visibility` | `private` / `public` / `unlisted` / `friends_only` |
| `changeNote` | 更新说明 |
| `tags` | 搜索标签（"Tools & APIs" 保留给工具类 mod） |
| `dependencies` | 依赖 mod 的 **Workshop ID**（在 workshop URL 里） |
| `contentDescriptors` | 成人内容描述（nudity 等） |
| `minBranch` / `maxBranch` | 支持的分支范围（behavior 怪，建议网页上改） |

初传后大部分字段可置 `null` 表示保持不变。出错时把 `mod-uploader.log` 发给开发组。

### Workshop 描述多语言（2026-08-20 实测）

Steam Workshop 的 UGC 元数据支持按语言保存标题与描述。官方 `ISteamUGC` 流程要求先调用 `SetItemUpdateLanguage`，再调用 `SetItemTitle` / `SetItemDescription`；语言代码使用 Steam API 代码：`english`、`schinese`（简体中文）、`tchinese`（繁體中文）。查询时可用 `SetLanguage` 取得指定语言，未提供对应翻译时以 English 为 fallback。

本机官方 ModUploader v0.2.0 的 `ModConfig` 目前只有单一 `title` / `description` 字段，`UploadCommand` 也没有调用 `SetItemUpdateLanguage`，所以不能靠现有 `workshop.json` 直接上传多语言字段。不要把多种语言拼在同一个描述中作为正式方案；应在 Workshop 网页的语言下拉选项分别维护，或使用调用上述 API 的扩展上传器。仓库 `deploy/VakuuPlayer/workshop.json` 保留 English fallback 与 `localizations` 翻译源资料。

## 10. Agent Sync（skillshare 我的工具）

**skillshare**（v0.20.25，本机 `/opt/homebrew/bin/skillshare`）支持把 **agent（单个 .md 文件）** 从单一源头同步到各 AI CLI。

### 本机现状（实测）
- Agent 源目录：`~/.config/skillshare/agents` — **尚不存在**（目前 0 个 agent）
- 已配置 agent 目标的 target：
  - `claude` → `~/.claude/agents`（本地已有 1 个：`paper-reader.md`）
  - `cursor` → `~/.cursor/agents`
  - `opencode` → `~/.config/opencode/agents`
- `codex` 未配 agent 目标（Codex 需要 TOML 格式，可用 extras + `codex-agents` 扩展做转换）
- skill 本体已同步到 6 个 target（universal/antigravity/claude/codex/cursor/opencode，merge 模式）

### 常用命令
```bash
skillshare sync agents                    # 把源 agent 同步到所有目标
skillshare collect agents claude          # 把本地 agent 收回到源头（反方向）
skillshare target claude --add-agent-include "team-*"   # agent 过滤
skillshare target claude --add-agent-exclude "draft-*"
skillshare target claude --agent-mode copy              # 改同步模式
skillshare list agents --json             # 查看 agent 清单
skillshare status --json                  # 含 agentSync/agentLinkedCount 状态
```

### 规则
- agent 格式：Claude 风格 markdown（frontmatter 含 `name`/`description` + 指令正文）
- 单文件即一个 agent；`.agentignore` 和 `enable`/`disable` 可做 per-agent 开关
- `extension:` 仅 extras 支持（如 MD → Codex TOML），原生 agents 目标不支持
- 项目内 agent 优先用 config 里原生 `agents:` 目标，需要 flatten/extension 才走 extras

### 联动建议
做 STS2 mod 时可以把模组专属 agent（如 "STS2 反编译助手"）写成一个 .md 放进 `~/.config/skillshare/agents`，然后 `skillshare sync agents` 分发到 claude/cursor/opencode。

### 本項目配置方式（2026-08-16 確定）
- 本項目**不使用 skillshare 項目級 agent**（`.skillshare/agents/` 已移除）
- 正確做法：repo 級 agent 指令 = 根目錄 `AGENTS.md`，由 **agent-rules 工具**管理：
  ```bash
  ~/.agents/skills/agent-rules/agents_rule --project "$PWD" init   # 注入 base block + CLAUDE.md symlink + 註冊 managed-repos.txt
  ~/.agents/skills/agent-rules/agents_rule --project "$PWD" docs    # scaffold docs/
  ```
- 全局 agent 指令（跨機器/跨工具）走 `~/.agents/AGENTS.md`，由 `transfer_MAC/scripts/sync-ai-agent-configs.py render` 分發 symlink 到 codex/claude/gemini/opencode 的 AGENTS.md/CLAUDE.md/GEMINI.md
- 已配置：`AGENTS.md`（base block + STS2 項目規則）、`docs/` 五件套、`~/.agents/managed-repos.txt` 已註冊

## 10.5 正確的測試/迭代方法（2026-08-16 搜尋確認，取代之前錯誤的 Workshop 上傳流程）

### 本地 mods 目錄（macOS）
- 位置：`<遊戲>/SlayTheSpire2.app/Contents/MacOS/mods/<ModId>/`（Windows/Linux 是遊戲根目錄 `mods/`）
- 之前把 mods 建在遊戲根目錄是錯的，導致誤以為只能從 Workshop 載入
- 本地版號大於 Workshop 版時，遊戲自動停用 Workshop 版、載入本地版
- **迭代流程：改碼 → `dotnet build` → 複製 dll/json 到 MacOS/mods → 重啟遊戲** — 零上傳
- 一鍵腳本：`./test.sh`（build + 部署 + 重啟）

### 開發者控制台（mods 啟用後）
- 按 `~` / `` ` `` / `*` / `'` / `Shift+8` 開關；`help` 列出命令、`help card` 看單命令
- 可即時生成內容測試（卡/遺物等）
- BaseLib 加 `showlog`（開 log 視窗）、`open logs`（開 log 目錄）；BaseLib 設定可「Open log window on startup」

### Log
- `~/Library/Application Support/SlayTheSpire2/logs/godot.log`
- mod 內用 `MainFile.Logger.Info(...)` 打自訂 log

### 除錯器（IDE）
- 遊戲目錄放 `steam_appid.txt`（內容 2868840）→ 可直接從 Rider/VS 啟動遊戲並斷點
- mod 的 `.pdb` 複製到 dll 旁（csproj 加 Copy 目標）

### 多人本地測試
- `-fastmp host_standard`（主機）/ `-fastmp join`（客戶端）/ `-fastmp join -clientId 1001`（第三人）

### 資源變更
- 只改 .cs → 只 Build（複製 dll）；改資源/本地化/場景 → 需 Publish（Godot 打包 pck）

### 工具生態
- **KitLib**（Workshop）：測試 run、遊戲內編輯卡牌/狀態、log viewer、pseudo co-op、unlock all
- **STS2 Modding MCP**：反編譯/建置/部署/自動試玩（151 工具）
- **TemplateMod（doctornoodlearms）**：Godot `--remote-debug tcp://127.0.0.1:6007` 接 editor console

### STS1（一代）參考（方法論成熟，可借鑒）
- ModTheSpire + BaseMod：載入器 + dev console；BaseMod 附 TestMod（每版回歸測試）
- StS-DefaultModBase 的 Maven 生命週期：F5 clean / F6 package / F7 debug（直接啟動遊戲調試）
- Java 8 限定

### Preserved Fog 開局生命週期（v0.111.0 實測）

`NGame.StartRun` 的關鍵順序為：

```text
PreloadRunAssets
→ RunManager.FinalizeStartingRelics
→ RunManager.Launch
→ NRun.Create
→ RunManager.EnterAct
```

`FinalizeStartingRelics` 逐一 await 起始遺物的 `AfterObtained()`；此時 `NRun.Instance` 與 `NOverlayStack.Instance` 尚不存在。因此不能在 Preserved Fog 的原生 `AfterObtained` 直接開 `NDeckCardSelectScreen`。

瓦庫目前的正確接法：

1. 單人瓦庫新 run 中，Harmony 精確攔截 Preserved Fog 的 `AfterObtained`，保存當時可移除牌的 snapshot，延後副作用。
2. `RunManager.EnterAct` 在 `NRun.Create` 後會初始化第一幕、觸發 `ActEntered`、淡入，再 await `Hook.AfterActEntered(runState)`。
3. `VakuuContract.AfterActEntered()` await 原生 `CardSelectCmd.FromDeckGeneric` 選牌 UI；以 snapshot filter 排除後續 SereTalon/DistinguishedCape 新增的牌。
4. 玩家選滿 3 張後用原生 `CardPileCmd.RemoveFromDeck`，再加入 Folly；任何例外直接讓 run 啟動失敗，不隨機刪牌。

不要用全域 `ShouldSelectLocalCard` patch：它不能建立 NRun/overlay，且會影響所有單人選牌。若 map 已在 `AfterActEntered` 時開啟，選牌協調器暫時關閉 map，完成後恢復。

### STS2 自動化/輔助工具
- **STS2 Modding MCP**（elliotttate/sts2-modding-mcp，153 tools）：反編譯、建置、部署、**live-inspect 運行中 Godot 引擎、自動 playtest**
- **KitLib**（STS2-KitLib）：測試 run（含 seed）、左緣 dev panel 遊戲內編輯卡牌/狀態、log viewer、pseudo co-op（雙實例 LAN）、unlock all
- **customjack/sts2_ExampleMod**：主選單開關（main-menu toggles）掛 5 個範例 — 適合做「測試選項」模式
- **TemplateMod（doctornoodlearms）**：Godot `--remote-debug tcp://127.0.0.1:6007` 接 editor console；mod 首次載入用獨立 save（不用怕壞進度）
- **romgenie STS2 MCP wrapper**：VM 部署測試流程參考

## 11. 版本对齐（本机实测）

- `release_info.json`: v0.111.0, commit 41cef1ea (2026-08-13)
- `sts2.runtimeconfig.json`: net9.0 / runtime 9.0.7
- data 目录: `data_sts2_macos_arm64`（本机是 arm64）
- Workshop 内容目录: `~/Library/Application Support/Steam/steamapps/workshop/content/2868840/`（已含 BaseLib）
