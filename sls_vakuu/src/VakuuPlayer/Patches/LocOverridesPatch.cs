using System;
using System.Collections.Generic;
using HarmonyLib;
using MegaCrit.Sts2.Core.Localization;

namespace VakuuPlayer.Patches;

[HarmonyPatch(typeof(LocManager), "LoadTablesFromPath")]
public static class LocOverridesPatch
{
    private static void Postfix(string language, ref (Dictionary<string, LocTable> tables, bool allowOverride, List<LocValidationError> errors) __result)
    {
        if (__result.tables == null || !__result.tables.TryGetValue("ancients", out var table))
        {
            return;
        }

        var text = language switch
        {
            "zht" => new[]
            {
                "醒來吧。你踏入這座尖塔，不是為了向涅奧乞求祝福。",
                "你想要力量？我會把我的一切都給你——榮耀、詛咒，以及每一份代價。",
                "你不必選擇。只有弱者才會在力量面前猶豫。",
                "把自己交給我，你就能變得和我一樣，令眾生畏懼。",
                "接受",
                "接受瓦庫的全部遺物。力量、詛咒、代價——一件不留。",
                "繼續"
            },
            "zhs" => new[]
            {
                "醒来吧。你踏入这座尖塔，不是为了向涅奥乞求祝福。",
                "你想要力量？我会把我的一切都给你——荣耀、诅咒，以及每一份代价。",
                "你不必选择。只有弱者才会在力量面前犹豫。",
                "把自己交给我，你就能变得和我一样，令众生畏惧。",
                "接受",
                "接受瓦库的全部遗物。力量、诅咒、代价——一件不留。",
                "继续"
            },
            _ => new[]
            {
                "Wake up. You did not enter this Spire to beg Neow for a blessing.",
                "You want power. I will give you everything I have—glory, curses, and every cost.",
                "You do not need to choose. Only the weak hesitate before power.",
                "Give yourself to me, and you will be feared as much as I.",
                "Accept",
                "Accept everything Vakuu offers: every relic, every curse, and every cost.",
                "Continue"
            }
        };

        var overrides = new Dictionary<string, string>
        {
            [$"{VakuuEventPatch.AcceptOptionKey}.title"] = text[4],
            [$"{VakuuEventPatch.AcceptOptionKey}.description"] = text[5],
            ["VAKUU.talk.firstVisitEver.0-0.ancient"] = text[0],
            ["VAKUU.talk.firstVisitEver.0-1.ancient"] = text[1],
            ["VAKUU.talk.firstVisitEver.0-2.ancient"] = text[2],
            ["VAKUU.talk.firstVisitEver.0-3.ancient"] = text[3],
            ["VAKUU.talk.firstVisitEver.0-0.next"] = text[6],
            ["VAKUU.talk.firstVisitEver.0-1.next"] = text[6],
            ["VAKUU.talk.firstVisitEver.0-2.next"] = text[6]
        };

        table.MergeWith(overrides);
        FileLog.Log($"VakuuPlayer: applied Vakuu opening localization ({overrides.Count} entries, lang={language})");
    }
}
