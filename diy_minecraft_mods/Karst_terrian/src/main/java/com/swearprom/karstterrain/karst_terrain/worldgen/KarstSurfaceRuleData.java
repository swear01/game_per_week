package com.swearprom.karstterrain.karst_terrain.worldgen;

import com.swearprom.karstterrain.karst_terrain.KarstTerrain;

import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.levelgen.SurfaceRules;

public final class KarstSurfaceRuleData {
    private static final SurfaceRules.RuleSource LIMESTONE = makeStateRule(KarstTerrain.LIMESTONE.get());
    private static final SurfaceRules.RuleSource WEATHERED_LIMESTONE = makeStateRule(KarstTerrain.WEATHERED_LIMESTONE.get());

    private KarstSurfaceRuleData() {
    }

    public static SurfaceRules.RuleSource makeRules() {
        return SurfaceRules.ifTrue(
                SurfaceRules.isBiome(KarstBiomes.KARST_HIGHLANDS),
                SurfaceRules.sequence(
                        SurfaceRules.ifTrue(SurfaceRules.ON_FLOOR, WEATHERED_LIMESTONE),
                        SurfaceRules.ifTrue(SurfaceRules.UNDER_FLOOR, LIMESTONE)));
    }

    private static SurfaceRules.RuleSource makeStateRule(Block block) {
        return SurfaceRules.state(block.defaultBlockState());
    }
}
