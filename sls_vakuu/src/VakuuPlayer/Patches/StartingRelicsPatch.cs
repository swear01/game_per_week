using System.Collections.Generic;
using System.Linq;
using HarmonyLib;
using MegaCrit.Sts2.Core.Entities.Relics;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Characters;
using MegaCrit.Sts2.Core.Models.Relics;

namespace VakuuPlayer.Patches;

/// <summary>
/// 所有角色開局遺物追加瓦庫的 10 件遺物（含負面效果）。
/// </summary>
public static class StartingRelicsPatch
{
    private static readonly RelicModel[] VakuuRelics =
    [
        ModelDb.Relic<WhisperingEarring>(),
        ModelDb.Relic<BloodSoakedRose>(),
        ModelDb.Relic<Fiddle>(),
        ModelDb.Relic<PreservedFog>(),
        ModelDb.Relic<SereTalon>(),
        ModelDb.Relic<DistinguishedCape>(),
        ModelDb.Relic<ChoicesParadox>(),
        ModelDb.Relic<MusicBox>(),
        ModelDb.Relic<LordsParasol>(),
        ModelDb.Relic<JeweledMask>(),
    ];

    private static void Postfix(ref IReadOnlyList<RelicModel> __result)
    {
        var list = __result.ToList();
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
