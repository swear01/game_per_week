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

    private static void Postfix(ref IReadOnlyList<RelicModel> __result)
    {
        var list = __result
            .Where(r => r.GetType() != typeof(WhisperingEarring)) // 低語耳環由瓦庫契約取代
            .ToList();
        list.AddRange(VakuuRelics);
        __result = list;
    }

    [HarmonyPatch(typeof(Ironclad), nameof(CharacterModel.StartingRelics), MethodType.Getter)]
    private static class IroncladPatch { }

    [HarmonyPatch(typeof(Silent), nameof(CharacterModel.StartingRelics), MethodType.Getter)]
    private static class SilentPatch { }

    [HarmonyPatch(typeof(Defect), nameof(CharacterModel.StartingRelics), MethodType.Getter)]
    private static class DefectPatch { }

    [HarmonyPatch(typeof(Regent), nameof(CharacterModel.StartingRelics), MethodType.Getter)]
    private static class RegentPatch { }

    [HarmonyPatch(typeof(Necrobinder), nameof(CharacterModel.StartingRelics), MethodType.Getter)]
    private static class NecrobinderPatch { }
}
