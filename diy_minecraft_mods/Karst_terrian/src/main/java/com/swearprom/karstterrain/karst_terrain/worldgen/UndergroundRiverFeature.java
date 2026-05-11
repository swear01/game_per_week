package com.swearprom.karstterrain.karst_terrain.worldgen;

import com.mojang.serialization.Codec;

import net.minecraft.core.BlockPos;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.FeaturePlaceContext;
import net.minecraft.world.level.levelgen.feature.configurations.NoneFeatureConfiguration;

public class UndergroundRiverFeature extends Feature<NoneFeatureConfiguration> {
    public UndergroundRiverFeature(Codec<NoneFeatureConfiguration> codec) {
        super(codec);
    }

    @Override
    public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> context) {
        WorldGenLevel level = context.level();
        RandomSource random = context.random();
        BlockPos origin = context.origin();
        int baseSurfaceY = KarstFeatureSupport.surfaceY(level, origin.getX(), origin.getZ());
        if (baseSurfaceY < 56 || baseSurfaceY > 220) {
            return false;
        }

        int minX = origin.getX() & ~15;
        int minZ = origin.getZ() & ~15;
        boolean eastWest = random.nextBoolean();
        int channelOffset = 5 + random.nextInt(7);
        double phase = random.nextDouble() * Math.PI * 2.0;
        int baseWaterY = Mth.clamp(baseSurfaceY - (4 + random.nextInt(5)), 20, 118);
        int radius = 2 + random.nextInt(2);
        int carved = 0;

        for (int step = -4; step <= 20; step++) {
            double bend = Math.sin((step * 0.42) + phase) * 3.0;
            int ix = eastWest ? minX + step : minX + channelOffset + Mth.floor(bend);
            int iz = eastWest ? minZ + channelOffset + Mth.floor(bend) : minZ + step;

            int localSurface = KarstFeatureSupport.surfaceY(level, ix, iz);
            int waterY = Math.min(baseWaterY, localSurface - 1);
            int coverDepth = localSurface - waterY;
            boolean exposed = coverDepth <= 3 || step % 9 == 0;
            carved += carveRiverSection(level, origin, ix, waterY, iz, radius, exposed, localSurface);
        }

        return carved > 60;
    }

    private static int carveRiverSection(
            WorldGenLevel level,
            BlockPos origin,
            int centerX,
            int waterY,
            int centerZ,
            int radius,
            boolean exposed,
            int surfaceY) {
        int carved = 0;
        int topY = exposed ? surfaceY + 1 : waterY + 4;
        int bottomY = waterY - 1;

        for (int dx = -radius; dx <= radius; dx++) {
            for (int dz = -radius; dz <= radius; dz++) {
                double dist = Math.sqrt(dx * dx + dz * dz);
                if (dist > radius + 0.25) {
                    continue;
                }

                for (int y = bottomY; y <= topY; y++) {
                    BlockPos pos = new BlockPos(centerX + dx, y, centerZ + dz);
                    if (!KarstFeatureSupport.isInsideOriginChunk(origin, pos)) {
                        continue;
                    }

                    if (y == waterY && dist <= radius - 0.35) {
                        KarstFeatureSupport.setIfWritable(level, origin, pos, Blocks.WATER.defaultBlockState());
                        carved++;
                    } else if (y > waterY) {
                        if (!KarstFeatureSupport.canCarve(level.getBlockState(pos))) {
                            continue;
                        }
                        KarstFeatureSupport.setIfWritable(level, origin, pos, Blocks.CAVE_AIR.defaultBlockState());
                        carved++;
                    } else {
                        KarstFeatureSupport.replaceIfKarst(level, origin, pos, KarstFeatureSupport.limestoneShellState(pos.getX(), pos.getY(), pos.getZ()));
                        carved++;
                    }
                }
            }
        }
        lineRiverBanks(level, origin, centerX, waterY, centerZ, radius, exposed ? surfaceY : waterY + 4);
        return carved;
    }

    private static void lineRiverBanks(WorldGenLevel level, BlockPos origin, int centerX, int waterY, int centerZ, int radius, int topY) {
        for (int dx = -radius - 1; dx <= radius + 1; dx++) {
            for (int dz = -radius - 1; dz <= radius + 1; dz++) {
                double dist = Math.sqrt(dx * dx + dz * dz);
                if (dist < radius || dist > radius + 1.45) {
                    continue;
                }
                for (int y = waterY - 1; y <= topY; y++) {
                    BlockPos pos = new BlockPos(centerX + dx, y, centerZ + dz);
                    KarstFeatureSupport.replaceIfKarst(level, origin, pos, KarstFeatureSupport.limestoneShellState(pos.getX(), pos.getY(), pos.getZ()));
                }
            }
        }
    }
}
