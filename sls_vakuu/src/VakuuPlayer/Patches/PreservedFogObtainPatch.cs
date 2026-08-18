using System.Threading.Tasks;
using HarmonyLib;
using MegaCrit.Sts2.Core.Models.Relics;

namespace VakuuPlayer.Patches;

[HarmonyPatch(typeof(PreservedFog), nameof(PreservedFog.AfterObtained))]
internal static class PreservedFogObtainPatch
{
    private static bool Prefix(PreservedFog __instance, ref Task __result)
    {
        if (!PreservedFogStartupCoordinator.TryDefer(__instance))
        {
            return true;
        }

        __result = Task.CompletedTask;
        return false;
    }
}
