using HarmonyLib;
using MegaCrit.Sts2.Core.Modding;
using MegaCrit.Sts2.Core.Models.RelicPools;
using VakuuPlayer.Relics;

namespace VakuuPlayer;

/// <summary>Vakuu Player mod 入口：第一幕由瓦庫開局，取得全部遺物並接管每一回合。</summary>
[ModInitializer(nameof(Initialize))]
public static class ModEntry
{
    public static void Initialize()
    {
        ModHelper.AddModelToPool<SharedRelicPool, VakuuContract>();
        new Harmony("vakuuplayer.mod").PatchAll(typeof(ModEntry).Assembly);
    }
}
