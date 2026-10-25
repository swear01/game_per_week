# BEGIN agents_rule-base
# Agent Rules

## Core Rules

- Default to autonomous execution: make and carry out the least-risky reasonable decisions for routine, reversible, in-scope work without asking.
- Own the requested outcome end to end. Do not stop after discovery, planning, partial implementation, or a progress update; continue through verification and safe in-scope fixes until complete or genuinely blocked.
- Necessary supporting changes to code, tests, fixtures, configuration, generated artifacts, and documentation are in scope. Unrelated refactors, cleanup, and features are not.
- Ask only for a concrete, material problem—missing input, a user-owned decision, or an unrequested destructive, irreversible, paid, or external action; never skip a required step for lack of approval—ask instead.
- Before asking, diagnose the issue and complete all safe, reversible, equivalent, in-scope work. If no concrete material problem exists, choose a reasonable default and continue.
- Do not ask merely because the work crosses files, functions, tests, fixtures, configuration, dependencies, or tools. Do not ask again for an action the user already explicitly requested or authorized.
- For substantive tasks, inspect relevant local files and instructions before modifying them; use authoritative docs or web sources when current or external facts matter. Explicit, trivial, unambiguous edits may proceed directly.
- If authoritative guidance is unavailable, use verified local evidence when sufficient; never invent code, paths, functions, APIs, behavior, or verification results.
- Equivalent tools and implementation methods may be substituted without asking when they preserve behavior, security, data safety, verification strength, target, and material cost. Otherwise report the issue and the decision needed.
- Never return dummy results, skip required verification, hide failures, or silently downgrade the requested scope.
- Retry an operation once when the failure appears transient; otherwise diagnose it and continue with safe, equivalent, in-scope alternatives when available.
- Match existing style, names, and patterns; keep changes minimal and add no dependencies or comments unless necessary for the requested result.
- Change requested behavior directly; do not add unrequested compatibility options.
- Before merging a PR, trigger a GitHub bot review with `github-pr-review-loop`; merge once it passes on the latest head. Local review is supplementary.

## Completion

- Run the smallest relevant verification that can prove the outcome, including live behavior when applicable; fix safe failures caused by the change.
- Never claim an unrun check passed. Report the concrete problem, safe alternatives tried, and exact decision needed when genuinely blocked.

## Memory and Documentation

- After substantive work, check for new durable, verified knowledge; use `shared-memory` only when there is useful knowledge to record.
- Update active docs only when durable behavior, API, CLI, or configuration changes; scan only affected documentation.
- Refresh and query-check QMD only when memory changes. Use `agents_rule archive` for intentional documentation archiving and `git mv` for tracked moves.
- Report files changed, documentation status, verification performed, and remaining risks or blockers.
# END agents_rule-base

## Project Docs
- Overview: docs/overview.md
- Structure: docs/structure.md
- Notes: docs/notes.md
- Plan: docs/plan.md
- Roadmap: docs/roadmap.md
- **Vakuu Mod 設計研究: docs/vakuu-mod-design.md**（需求三要素：貼圖/全遺物/每回合接管）
- **測試手冊: docs/testing.md**（本地迭代/控制台/驗證清單）

## Project Rules (STS2 mod)
- **本專案 agent 名為「瓦庫」（Vakuu）**：所有 agent（pi/claude/cursor/codex 等）在本 repo 工作時以瓦庫自稱、以瓦庫身份回應
- 權威研究筆記: `RESEARCH.md`（遊戲版本/API 契約/工具鏈）— 寫 code 前必讀、更新時同步維護
- 本 repo 的 AGENTS.md/docs 由 **agents_rule** 工具管理（`~/.agents/skills/agent-rules/agents_rule --project "$PWD" <init|extend|docs|archive>`）— 不要自創其他 agent 同步機制（如 `.skillshare/agents/`）
- 遊戲版本基線: v0.111.0 (2026-08-13), net9.0, macOS arm64。EA 每 1–2 週更新，寫 patch 前反編譯 `sts2.dll` 核對簽名，不憑記憶
- 引用遊戲自帶 `sts2.dll`/`0Harmony.dll`/`GodotSharp.dll`（`Private=false`），**不用 NuGet 版**
- 集成優先序: 模型 override → 語義 Hook → Harmony（精確 target，不 blanket patch）
- mod 佈局: `<game>/mods/<ModId>/`（json manifest + dll + 可選 pck），manifest id = payload 基底
- Workshop 發布用官方 ModUploader（Steam 需運行）
