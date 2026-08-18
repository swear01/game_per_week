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
            "zht" => (
                Line0: "醒來吧。你踏入這座尖塔，不是為了向涅奧乞求祝福。",
                Line1: "你想要力量？我會把我的一切都給你——榮耀、詛咒，以及每一份代價。",
                Line2: "你不必選擇。只有弱者才會在力量面前猶豫。",
                Line3: "把自己交給我，你就能變得和我一樣，令眾生畏懼。",
                OptionTitle: "接受",
                OptionDescription: "接受瓦庫的全部遺物。力量、詛咒、代價——一件不留。",
                Next: "繼續"),
            "zhs" => (
                Line0: "醒来吧。你踏入这座尖塔，不是为了向涅奥乞求祝福。",
                Line1: "你想要力量？我会把我的一切都给你——荣耀、诅咒，以及每一份代价。",
                Line2: "你不必选择。只有弱者才会在力量面前犹豫。",
                Line3: "把自己交给我，你就能变得和我一样，令众生畏惧。",
                OptionTitle: "接受",
                OptionDescription: "接受瓦库的全部遗物。力量、诅咒、代价——一件不留。",
                Next: "继续"),
            _ => (
                Line0: "Wake up. You did not enter this Spire to beg Neow for a blessing.",
                Line1: "You want power. I will give you everything I have—glory, curses, and every cost.",
                Line2: "You do not need to choose. Only the weak hesitate before power.",
                Line3: "Give yourself to me, and you will be feared as much as I.",
                OptionTitle: "Accept",
                OptionDescription: "Accept everything Vakuu offers: every relic, every curse, and every cost.",
                Next: "Continue")
        };

        var overrides = new Dictionary<string, string>
        {
            [$"{VakuuEventPatch.AcceptOptionKey}.title"] = text.OptionTitle,
            [$"{VakuuEventPatch.AcceptOptionKey}.description"] = text.OptionDescription,
            ["VAKUU.talk.firstVisitEver.0-0.ancient"] = text.Line0,
            ["VAKUU.talk.firstVisitEver.0-1.ancient"] = text.Line1,
            ["VAKUU.talk.firstVisitEver.0-2.ancient"] = text.Line2,
            ["VAKUU.talk.firstVisitEver.0-3.ancient"] = text.Line3,
            ["VAKUU.talk.firstVisitEver.0-0.next"] = text.Next,
            ["VAKUU.talk.firstVisitEver.0-1.next"] = text.Next,
            ["VAKUU.talk.firstVisitEver.0-2.next"] = text.Next
        };

        table.MergeWith(overrides);
        FileLog.Log($"VakuuPlayer: applied Vakuu opening localization ({overrides.Count} entries, lang={language})");
    }
}
