using HarmonyLib;
using MegaCrit.Sts2.Core.Modding;
using MegaCrit.Sts2.Core.Models.RelicPools;
using VakuuPlayer.Relics;

namespace VakuuPlayer;

/// <summary>Vakuu Player mod 入口：玩家開局拿到全部瓦庫遺物，瓦庫接管每一回合。</summary>
[ModInitializer(nameof(Initialize))]
public static class ModEntry
{
    public static void Initialize()
    {
        ModHelper.AddModelToPool<SharedRelicPool, VakuuContract>();
        new Harmony("vakuuplayer.mod").PatchAll(typeof(ModEntry).Assembly);
    }
}
