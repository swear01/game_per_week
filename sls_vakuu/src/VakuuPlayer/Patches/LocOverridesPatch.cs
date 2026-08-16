using System.Collections.Generic;
using System.Linq;
using HarmonyLib;
using MegaCrit.Sts2.Core.Localization;

namespace VakuuPlayer.Patches;

/// <summary>
/// 本地化覆蓋（表載入完成後套用，語言切換時自動重跑）：
/// ancients：涅奧（NEOW）保持顯示，台詞換成瓦庫的契約之語（值從 VAKUU.talk.* 複製）。
/// 選角色頁面不改（角色名保持原樣）。
/// </summary>
[HarmonyPatch(typeof(LocManager), "LoadTablesFromPath")]
public static class LocOverridesPatch
{
    private static void Postfix(string language, ref (Dictionary<string, LocTable> tables, bool allowOverride, List<LocValidationError> errors) __result)
    {
        try
        {
            if (__result.tables == null || !__result.tables.TryGetValue("ancients", out var table))
            {
                return;
            }

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
                FileLog.Log($"VakuuPlayer: Neow dialogue overridden with Vakuu's lines ({overrides.Count} entries, lang={language})");
            }
        }
        catch (System.Exception e)
        {
            FileLog.Log($"VakuuPlayer: loc override failed: {e.Message}");
        }
    }
}
