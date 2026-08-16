using System.Collections.Generic;
using System.Linq;
using HarmonyLib;
using MegaCrit.Sts2.Core.Localization;

namespace VakuuPlayer.Patches;

/// <summary>
/// 本地化覆蓋（表載入完成後套用，語言切換時自動重跑）：
/// 1. ancients：涅奧（NEOW）保持顯示，台詞換成瓦庫的契約之語（值從 VAKUU.talk.* 複製）。
/// 2. characters：所有角色名改為「瓦庫」（玩家就是瓦庫）。
/// </summary>
[HarmonyPatch(typeof(LocManager), "LoadTablesFromPath")]
public static class LocOverridesPatch
{
    private static readonly string[] PlayerCharacterKeys =
    [
        "IRONCLAD.title", "IRONCLAD.titleObject",
        "SILENT.title", "SILENT.titleObject",
        "DEFECT.title", "DEFECT.titleObject",
        "REGENT.title", "REGENT.titleObject",
        "NECROBINDER.title", "NECROBINDER.titleObject",
    ];

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

            if (__result.tables.TryGetValue("characters", out var characters))
            {
                ApplyPlayerNameOverrides(characters, language);
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

    private static void ApplyPlayerNameOverrides(LocTable table, string language)
    {
        var playerName = language == "zht" ? "瓦庫" : "Vakuu";
        var overrides = PlayerCharacterKeys
            .Where(table.HasEntry)
            .ToDictionary(k => k, _ => playerName);
        if (overrides.Count > 0)
        {
            table.MergeWith(overrides);
            FileLog.Log($"VakuuPlayer: player name overridden to '{playerName}' ({overrides.Count} entries, lang={language})");
        }
    }
}
