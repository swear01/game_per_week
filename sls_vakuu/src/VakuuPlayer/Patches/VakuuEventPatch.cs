using System;
using System.Collections.Generic;
using System.Reflection;
using System.Threading.Tasks;
using HarmonyLib;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Ancients;
using MegaCrit.Sts2.Core.Events;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Events;
using MegaCrit.Sts2.Core.Models.Relics;
using VakuuPlayer.Relics;

namespace VakuuPlayer.Patches;

internal static class VakuuEventPatch
{
    internal const string AcceptOptionKey = "VAKUU.pages.INITIAL.options.ACCEPT";

    private static readonly MethodInfo DoneMethod =
        AccessTools.Method(typeof(AncientEventModel), "Done", Type.EmptyTypes)
        ?? throw new MissingMethodException(typeof(AncientEventModel).FullName, "Done()");

    [HarmonyPatch(typeof(Vakuu), "DefineDialogues")]
    private static class OpeningDialoguePatch
    {
        private static readonly MethodInfo FirstVisitEverSetter =
            AccessTools.PropertySetter(typeof(AncientDialogueSet), nameof(AncientDialogueSet.FirstVisitEverDialogue))
            ?? throw new MissingMethodException(typeof(AncientDialogueSet).FullName, "FirstVisitEverDialogue setter");

        private static void Postfix(ref AncientDialogueSet __result)
        {
            FirstVisitEverSetter.Invoke(__result, [new AncientDialogue("", "", "", "")]);
        }
    }

    [HarmonyPatch(typeof(Vakuu), "GenerateInitialOptions")]
    private static class InitialOptionsPatch
    {
        private static bool Prefix(Vakuu __instance, ref IReadOnlyList<EventOption> __result)
        {
            if (__instance.Owner == null)
            {
                return true;
            }

            var title = new LocString("ancients", $"{AcceptOptionKey}.title");
            var description = new LocString("ancients", $"{AcceptOptionKey}.description");
            __result =
            [
                new EventOption(
                    __instance,
                    () => GrantAllAsync(__instance),
                    title,
                    description,
                    AcceptOptionKey,
                    Array.Empty<IHoverTip>())
            ];
            return false;
        }
    }

    private static async Task GrantAllAsync(Vakuu eventModel)
    {
        var owner = eventModel.Owner ?? throw new InvalidOperationException("Vakuu has no owner.");

        await RelicCmd.Obtain<BloodSoakedRose>(owner);
        await RelicCmd.Obtain<Fiddle>(owner);
        await RelicCmd.Obtain<PreservedFog>(owner);
        await RelicCmd.Obtain<SereTalon>(owner);
        await RelicCmd.Obtain<DistinguishedCape>(owner);
        await RelicCmd.Obtain<ChoicesParadox>(owner);
        await RelicCmd.Obtain<MusicBox>(owner);
        await RelicCmd.Obtain<LordsParasol>(owner);
        await RelicCmd.Obtain<JeweledMask>(owner);
        await RelicCmd.Obtain<VakuuContract>(owner);

        DoneMethod.Invoke(eventModel, null);
    }
}
