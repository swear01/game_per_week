using HarmonyLib;
using MegaCrit.Sts2.Core.Entities.Ancients;
using MegaCrit.Sts2.Core.Localization;

namespace VakuuPlayer.Patches;

/// <summary>
/// 開局（Neow）對話替換成瓦庫的台詞：把 NEOW.talk.* key 換成對應的 VAKUU.talk.* key
/// （遊戲兩種對話結構相同，瓦庫對每個角色都有對應台詞）。
/// </summary>
[HarmonyPatch(typeof(AncientDialogue), nameof(AncientDialogue.PopulateLines))]
public static class NeowDialoguePatch
{
    private static void Postfix(AncientDialogue __instance, string ancientEntry)
    {
        if (ancientEntry != "NEOW")
        {
            return;
        }

        var replaced = 0;
        foreach (var line in __instance.Lines)
        {
            var loc = line.LineText;
            if (loc == null || loc.LocTable != "ancients" || !loc.LocEntryKey.StartsWith("NEOW.talk."))
            {
                continue;
            }

            var vakuuKey = "VAKUU" + loc.LocEntryKey.Substring("NEOW".Length);
            if (LocString.Exists("ancients", vakuuKey))
            {
                line.LineText = new LocString("ancients", vakuuKey);
                replaced++;
            }
        }

        if (replaced > 0)
        {
            FileLog.Log($"VakuuPlayer: replaced {replaced} Neow dialogue line(s) with Vakuu's");
        }
    }
}
