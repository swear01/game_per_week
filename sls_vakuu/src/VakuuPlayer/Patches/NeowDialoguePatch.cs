using System.Collections.Generic;
using System.Linq;
using HarmonyLib;
using MegaCrit.Sts2.Core.Localization;

namespace VakuuPlayer.Patches;

/// <summary>
/// 開局對話：涅奧（NEOW）保持顯示，但台詞換成瓦庫的契約之語。
/// 做法：不換 key（顯示的說話者由 key 前綴決定，必須保持 NEOW），
/// 在本地化表載入完成後，把 ancients 表裡 NEOW.talk.* 的值覆蓋為對應 VAKUU.talk.* 的文本。
/// 文本從表內複製，自動跟隨遊戲語言（eng / zht）；語言切換重新載入表時會再次套用。
/// </summary>
[HarmonyPatch(typeof(LocManager), "LoadTablesFromPath")]
public static class NeowDialoguePatch
{
    private static void Postfix(ref (Dictionary<string, LocTable> tables, bool allowOverride, List<LocValidationError> errors) __result)
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
                FileLog.Log($"VakuuPlayer: Neow dialogue overridden with Vakuu's lines ({overrides.Count} entries)");
            }
        }
        catch (System.Exception e)
        {
            FileLog.Log($"VakuuPlayer: Neow override failed: {e.Message}");
        }
    }
}
