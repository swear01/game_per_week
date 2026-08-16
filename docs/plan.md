# Plan

## In Progress
- 研究階段完成 ✅（RESEARCH.md 已含：技術棧、manifest 契約、Hook/Harmony、Workshop 上傳、agent sync 體系）
- Repo agent 配置完成 ✅（agents_rule init + docs/ scaffold）

## Next Up
1. **安裝 .NET 9 SDK**（`brew install dotnet-sdk`）— 本機目前沒有 dotnet
2. **搭建第一個 mod 骨架**：net9.0 classlib，csproj 引用遊戲三件套 DLL（GameDir/Sts2DataDir 走 MSBuild 屬性），建 `build/mods/<ModId>/` 暫存結構
3. **Hello mod**：最小 manifest + `[ModInitializer]` + 一張自訂卡牌（對照 RESEARCH.md §10 範例），部署到遊戲 `mods/` 驗證載入
4. 決定用 BaseLib 模板還是裸 csproj 起步
