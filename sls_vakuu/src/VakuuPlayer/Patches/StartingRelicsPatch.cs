using System;
using System.Collections.Generic;
using HarmonyLib;
using MegaCrit.Sts2.Core.Entities.Relics;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Characters;
using MegaCrit.Sts2.Core.Models.Relics;
using MegaCrit.Sts2.Core.Nodes.Screens.CharacterSelect;

namespace VakuuPlayer.Patches;

/// <summary>清空新局原生起始遺物；角色頁預覽仍顯示原生遺物。</summary>
public static class StartingRelicsPatch
{
    private static bool _showCharacterSelectPreview;

    private static void Apply(ref IReadOnlyList<RelicModel> result)
    {
        if (_showCharacterSelectPreview)
        {
            return;
        }

        result = Array.Empty<RelicModel>();
    }

    [HarmonyPatch(typeof(NCharacterSelectScreen), nameof(NCharacterSelectScreen.SelectCharacter))]
    [HarmonyPriority(Priority.First)]
    private static class CharacterSelectPreviewPatch
    {
        private static void Prefix() => _showCharacterSelectPreview = true;

        private static void Finalizer() => _showCharacterSelectPreview = false;
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
