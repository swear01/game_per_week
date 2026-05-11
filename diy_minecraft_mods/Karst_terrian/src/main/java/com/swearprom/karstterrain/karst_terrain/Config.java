package com.swearprom.karstterrain.karst_terrain;

import net.neoforged.neoforge.common.ModConfigSpec;

public class Config {
    private static final ModConfigSpec.Builder BUILDER = new ModConfigSpec.Builder();

    public static final ModConfigSpec.BooleanValue ENABLE_KARST_DIMENSION_HINT = BUILDER
            .comment("Reserved for future config-driven karst world generation tuning.")
            .define("enableKarstDimensionHint", true);

    public static final ModConfigSpec SPEC = BUILDER.build();
}
