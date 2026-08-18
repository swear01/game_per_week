using System.Collections.Generic;
using System.Linq;
using HarmonyLib;
using MegaCrit.Sts2.Core.Localization;

namespace VakuuPlayer.Patches;

/// <summary>
/// 本地化覆蓋（表載入完成後套用，語言切換時自動重跑）：
/// 1. ancients：涅奧（NEOW）保持顯示，台詞換成瓦庫的契約之語（值從 VAKUU.talk.* 複製）。
/// 2. relics：瓦庫契約（VAKUU_CONTRACT）的 title/description/flavor（遊戲內沒有此 key）。
/// 選角色頁面不改（角色名保持原樣）。
/// </summary>
[HarmonyPatch(typeof(LocManager), "LoadTablesFromPath")]
public static class LocOverridesPatch
{
    private static void Postfix(string language, ref (Dictionary<string, LocTable> tables, bool allowOverride, List<LocValidationError> errors) __result)
    {
        try
        {
            if (__result.tables == null)
            {
                return;
            }

            if (__result.tables.TryGetValue("ancients", out var ancients))
            {
                ApplyNeowOverrides(ancients);
            }

            if (__result.tables.TryGetValue("relics", out var relics))
            {
                ApplyVakuuContractLoc(relics, language);
            }
        }
        catch (System.Exception e)
        {
            FileLog.Log($"VakuuPlayer: loc override failed: {e.Message}");
        }
    }

    private static void ApplyNeowOverrides(LocTable table)
    {
        var overrides = new Dictionary<string, string>();
        foreach (var neowKey in table.Keys.Where(k => k.StartsWith("NEOW.talk.")))
        {
            var vakuuKey = "VAKUU" + neowKey.Substring("NEOW".Length);
            if (table.HasEntry(vakuuKey) && table.HasEntry(neowKey))
            {
                overrides[neowKey] = table.GetRawText(vakuuKey);
            }
        }

        if (overrides.Count > 0)
        {
            table.MergeWith(overrides);
            FileLog.Log($"VakuuPlayer: Neow dialogue overridden with Vakuu's lines ({overrides.Count} entries)");
        }
    }

    private static void ApplyVakuuContractLoc(LocTable table, string language)
    {
        var isZht = language == "zht";
        var overrides = new Dictionary<string, string>
        {
            ["VAKUU_CONTRACT.title"] = isZht ? "瓦庫契約" : "Vakuu's Contract",
            ["VAKUU_CONTRACT.description"] = isZht
                ? "每回合開始 +1 能量。瓦庫接管你的每一回合：從左到右自動打牌，直到無牌可打、能量耗盡或打滿 13 張。"
                : "Gain 1 Energy at the start of each turn. Vakuu plays every turn for you: auto-plays cards left to right until no playable cards, no energy, or 13 cards played.",
            ["VAKUU_CONTRACT.flavor"] = isZht
                ? "把你自己交給我，你就能變得和我一樣萬眾畏懼。"
                : "Give yourself to me and you will be feared as much as I.",
        };
        table.MergeWith(overrides);
        FileLog.Log($"VakuuPlayer: VakuuContract localization added ({language})");
    }
}
