package com.swearprom.karstterrain.karst_terrain.worldgen;

import com.swearprom.karstterrain.karst_terrain.KarstTerrain;

import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.configurations.NoneFeatureConfiguration;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredRegister;

public final class KarstFeatures {
    public static final DeferredRegister<Feature<?>> FEATURES = DeferredRegister.create(BuiltInRegistries.FEATURE, KarstTerrain.MODID);

    public static final DeferredHolder<Feature<?>, Feature<NoneFeatureConfiguration>> KARST_PEAK_CLUSTER = FEATURES.register(
            "karst_peak_cluster",
            () -> new KarstPeakClusterFeature(NoneFeatureConfiguration.CODEC));
    public static final DeferredHolder<Feature<?>, Feature<NoneFeatureConfiguration>> KARST_CAVERN = FEATURES.register(
            "karst_cavern",
            () -> new KarstCavernFeature(NoneFeatureConfiguration.CODEC));
    public static final DeferredHolder<Feature<?>, Feature<NoneFeatureConfiguration>> UNDERGROUND_RIVER = FEATURES.register(
            "underground_river",
            () -> new UndergroundRiverFeature(NoneFeatureConfiguration.CODEC));

    private KarstFeatures() {
    }
}
