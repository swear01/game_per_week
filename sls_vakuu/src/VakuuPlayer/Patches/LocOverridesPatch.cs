using System.Collections.Generic;
using System.Linq;
using HarmonyLib;
using MegaCrit.Sts2.Core.Localization;
using MegaCrit.Sts2.Core.Models;
using VakuuPlayer.Relics;

namespace VakuuPlayer.Patches;

[HarmonyPatch(typeof(LocManager), "LoadTablesFromPath")]
public static class LocOverridesPatch
{
    private const string EnglishLanguage = "eng";
    private const string SimplifiedChineseLanguage = "zhs";
    private const string TraditionalChineseLanguage = "zht";

    private static void Postfix(string language, ref (Dictionary<string, LocTable> tables, bool allowOverride, List<LocValidationError> errors) __result)
    {
        if (__result.tables == null)
        {
            return;
        }

        var text = language switch
        {
            TraditionalChineseLanguage => (
                Line0: "醒來吧。你踏入這座尖塔，不是為了向涅奧乞求祝福。",
                Line1: "你想要力量？我會把我的一切都給你——榮耀、詛咒，以及每一份代價。",
                Line2: "你不必選擇。只有弱者才會在力量面前猶豫。",
                Line3: "把自己交給我，你就能變得和我一樣，令眾生畏懼。",
                OptionTitle: "接受",
                OptionDescription: "接受瓦庫的全部遺物。力量、詛咒、代價——一件不留。",
                Next: "繼續",
                ContractTitle: "瓦庫契約",
                ContractDescription: "每回合開始時，獲得 {Energy:energyIcons()}。[red]瓦庫會替你進行每一個回合。[/red]",
                ContractFlavor: "把你自己交給我，你就能變得和我一樣萬眾畏懼。"),
            SimplifiedChineseLanguage => (
                Line0: "醒来吧。你踏入这座尖塔，不是为了向涅奥乞求祝福。",
                Line1: "你想要力量？我会把我的一切都给你——荣耀、诅咒，以及每一份代价。",
                Line2: "你不必选择。只有弱者才会在力量面前犹豫。",
                Line3: "把自己交给我，你就能变得和我一样，令众生畏惧。",
                OptionTitle: "接受",
                OptionDescription: "接受瓦库的全部遗物。力量、诅咒、代价——一件不留。",
                Next: "继续",
                ContractTitle: "瓦库契约",
                ContractDescription: "在每个回合开始时，获得{Energy:energyIcons()}。[red]瓦库将接管你的每个回合。[/red]",
                ContractFlavor: "把你自己交给我，你就能变得和我一样令人畏惧。"),
            _ => (
                Line0: "Wake up. You did not enter this Spire to beg Neow for a blessing.",
                Line1: "You want power. I will give you everything I have—glory, curses, and every cost.",
                Line2: "You do not need to choose. Only the weak hesitate before power.",
                Line3: "Give yourself to me, and you will be feared as much as I.",
                OptionTitle: "Accept",
                OptionDescription: "Accept everything Vakuu offers: every relic, every curse, and every cost.",
                Next: "Continue",
                ContractTitle: "Vakuu's Contract",
                ContractDescription: "Gain {Energy:energyIcons()} at the start of each turn. [red]Vakuu plays every turn for you.[/red]",
                ContractFlavor: "Give yourself to me and you will be feared as much as I.")
        };

        if (__result.tables.TryGetValue("relics", out var relics))
        {
            var contractKey = ModelDb.GetId<VakuuContract>().Entry;
            relics.MergeWith(new Dictionary<string, string>
            {
                [$"{contractKey}.title"] = text.ContractTitle,
                [$"{contractKey}.description"] = text.ContractDescription,
                [$"{contractKey}.flavor"] = text.ContractFlavor
            });
            FileLog.Log($"VakuuPlayer: applied VakuuContract localization (lang={language})");
        }

        if (!__result.tables.TryGetValue("ancients", out var table))
        {
            return;
        }

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
        ApplyNeowOverrides(table);
        FileLog.Log($"VakuuPlayer: applied Vakuu opening localization ({overrides.Count} entries, lang={language})");
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
}
