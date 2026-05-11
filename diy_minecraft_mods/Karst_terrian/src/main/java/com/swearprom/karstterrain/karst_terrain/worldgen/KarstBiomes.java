package com.swearprom.karstterrain.karst_terrain.worldgen;

import com.swearprom.karstterrain.karst_terrain.KarstTerrain;

import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.biome.Biome;

public final class KarstBiomes {
    public static final ResourceKey<Biome> KARST_HIGHLANDS = register("karst_highlands");

    private KarstBiomes() {
    }

    private static ResourceKey<Biome> register(String name) {
        return ResourceKey.create(Registries.BIOME, ResourceLocation.fromNamespaceAndPath(KarstTerrain.MODID, name));
    }
}
