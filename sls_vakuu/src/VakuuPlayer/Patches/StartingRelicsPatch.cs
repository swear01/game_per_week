using System.Collections.Generic;
using System.Linq;
using HarmonyLib;
using MegaCrit.Sts2.Core.Entities.Relics;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Characters;
using MegaCrit.Sts2.Core.Models.RelicPools;
using MegaCrit.Sts2.Core.Models.Relics;
using VakuuPlayer.Relics;

namespace VakuuPlayer.Patches;

/// <summary>
/// 所有角色開局遺物：低語耳環換成瓦庫契約（每回合接管），並追加其餘 9 件瓦庫遺物（含負面效果）。
/// 注意：Harmony PatchAll 要求 [HarmonyPatch] 與 patch 方法同類 — 每個角色一個嵌套類。
/// </summary>
public static class StartingRelicsPatch
{
    private static readonly RelicModel[] VakuuRelics =
    [
        ModelDb.Relic<BloodSoakedRose>(),
        ModelDb.Relic<Fiddle>(),
        ModelDb.Relic<PreservedFog>(),
        ModelDb.Relic<SereTalon>(),
        ModelDb.Relic<DistinguishedCape>(),
        ModelDb.Relic<ChoicesParadox>(),
        ModelDb.Relic<MusicBox>(),
        ModelDb.Relic<LordsParasol>(),
        ModelDb.Relic<JeweledMask>(),
        ModelDb.Relic<VakuuContract>(),
    ];

    private static void Apply(ref IReadOnlyList<RelicModel> __result)
    {
        var list = __result
            .Where(r => r.GetType() != typeof(WhisperingEarring)) // 低語耳環由瓦庫契約取代
            .ToList();
        list.AddRange(VakuuRelics);
        __result = list;
        FileLog.Log($"VakuuPlayer: starting relics = {string.Join(", ", list.Select(r => r.GetType().Name))}");
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
