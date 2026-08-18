using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using HarmonyLib;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Acts;
using MegaCrit.Sts2.Core.Models.Events;
using MegaCrit.Sts2.Core.Runs;

namespace VakuuPlayer.Patches;

internal static class VakuuActPatch
{
    private static readonly FieldInfo RunStateField =
        AccessTools.Field(typeof(RunManager), "<State>k__BackingField")
        ?? throw new MissingFieldException(typeof(RunManager).FullName, "<State>k__BackingField");

    private static IEnumerable<AncientEventModel> FirstActAncient =>
        new[] { ModelDb.AncientEvent<Vakuu>() };

    [HarmonyPatch(typeof(Overgrowth), nameof(ActModel.AllAncients), MethodType.Getter)]
    private static class OvergrowthPatch
    {
        private static void Postfix(ref IEnumerable<AncientEventModel> __result) => __result = FirstActAncient;
    }

    [HarmonyPatch(typeof(Underdocks), nameof(ActModel.AllAncients), MethodType.Getter)]
    private static class UnderdocksPatch
    {
        private static void Postfix(ref IEnumerable<AncientEventModel> __result) => __result = FirstActAncient;
    }

    [HarmonyPatch(typeof(Glory), nameof(ActModel.AllAncients), MethodType.Getter)]
    private static class GloryPatch
    {
        private static void Postfix(ref IEnumerable<AncientEventModel> __result)
        {
            __result = __result.Where(ancient => ancient is not Vakuu).ToArray();
        }
    }

    [HarmonyPatch(typeof(RunManager), "SetStartedWithNeowFlag")]
    private static class StartedWithVakuuPatch
    {
        private static void Postfix(RunManager __instance)
        {
            var state = RunStateField.GetValue(__instance) as RunState
                ?? throw new InvalidOperationException("RunManager has no run state.");
            state.ExtraFields.StartedWithNeow = true;
        }
    }
}
