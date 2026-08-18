using System.Collections.Generic;
using HarmonyLib;
using MegaCrit.Sts2.Core.Entities.Relics;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Characters;

namespace VakuuPlayer.Patches;

/// <summary>清空角色原生起始遺物，改由第一幕 Vakuu 事件發放。</summary>
public static class StartingRelicsPatch
{
    private static void Apply(ref IReadOnlyList<RelicModel> __result)
    {
        __result = Array.Empty<RelicModel>();
    }

    [HarmonyPatch(typeof(Ironclad), nameof(CharacterModel.StartingRelics), MethodType.Getter)]
    private static class IroncladPatch
    {
        private static void Postfix(ref IReadOnlyList<RelicModel> __result) => Apply(ref __result);
    }

    [HarmonyPatch(typeof(Silent), nameof(CharacterModel.StartingRelics), MethodType.Getter)]
    private static class SilentPatch
    {
        private static void Postfix(ref IReadOnlyList<RelicModel> __result) => Apply(ref __result);
    }

    [HarmonyPatch(typeof(Defect), nameof(CharacterModel.StartingRelics), MethodType.Getter)]
    private static class DefectPatch
    {
        private static void Postfix(ref IReadOnlyList<RelicModel> __result) => Apply(ref __result);
    }

    [HarmonyPatch(typeof(Regent), nameof(CharacterModel.StartingRelics), MethodType.Getter)]
    private static class RegentPatch
    {
        private static void Postfix(ref IReadOnlyList<RelicModel> __result) => Apply(ref __result);
    }

    [HarmonyPatch(typeof(Necrobinder), nameof(CharacterModel.StartingRelics), MethodType.Getter)]
    private static class NecrobinderPatch
    {
        private static void Postfix(ref IReadOnlyList<RelicModel> __result) => Apply(ref __result);
    }
}
