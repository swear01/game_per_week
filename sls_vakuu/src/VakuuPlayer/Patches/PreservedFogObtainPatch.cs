using System.Threading.Tasks;
using HarmonyLib;
using MegaCrit.Sts2.Core.Models.Relics;

namespace VakuuPlayer.Patches;

[HarmonyPatch(typeof(PreservedFog), nameof(PreservedFog.AfterObtained))]
internal static class PreservedFogObtainPatch
{
    private static bool Prefix(PreservedFog __instance, ref Task __result)
    {
        if (!PreservedFogStartupCoordinator.TryDefer(__instance, out var failure))
        {
            return true;
        }

        __result = failure == null ? Task.CompletedTask : Task.FromException(failure);
        return false;
    }
}
