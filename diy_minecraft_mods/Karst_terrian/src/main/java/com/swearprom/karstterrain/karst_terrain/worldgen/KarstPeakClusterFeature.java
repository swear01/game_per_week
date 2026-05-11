package com.swearprom.karstterrain.karst_terrain.worldgen;

import com.mojang.serialization.Codec;
import com.swearprom.karstterrain.karst_terrain.KarstTerrain;

import net.minecraft.core.BlockPos;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.FeaturePlaceContext;
import net.minecraft.world.level.levelgen.feature.configurations.NoneFeatureConfiguration;

public class KarstPeakClusterFeature extends Feature<NoneFeatureConfiguration> {
    public KarstPeakClusterFeature(Codec<NoneFeatureConfiguration> codec) {
        super(codec);
    }

    @Override
    public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> context) {
        WorldGenLevel level = context.level();
        RandomSource random = context.random();
        BlockPos origin = context.origin();
        int placed = 0;
        int patchCount = 3 + random.nextInt(3);
        double trend = random.nextDouble() * Math.PI * 2.0;
        int baseX = origin.getX() + 8;
        int baseZ = origin.getZ() + 8;

        for (int i = 0; i < patchCount; i++) {
            double along = (i - (patchCount - 1) * 0.5) * 4.0;
            double side = random.nextInt(7) - 3;
            int centerX = baseX + Mth.floor(Math.cos(trend) * along + Math.cos(trend + Math.PI * 0.5) * side);
            int centerZ = baseZ + Mth.floor(Math.sin(trend) * along + Math.sin(trend + Math.PI * 0.5) * side);
            int surfaceY = KarstFeatureSupport.surfaceY(level, centerX, centerZ);
            if (surfaceY < 58 || surfaceY > 245) {
                continue;
            }

            int radius = 4 + random.nextInt(4);
            shapeKarstRelief(level, origin, centerX, centerZ, radius + 4, trend, random);
            carveSinkhole(level, origin, centerX, centerZ, radius, random);
            exposeKarstPavement(level, origin, centerX, centerZ, radius + 2, random);
            carveSurfaceFissures(level, origin, centerX, centerZ, radius + 4, trend, random);
            placed++;
        }

        return placed > 0;
    }

    private static void carveSinkhole(WorldGenLevel level, BlockPos origin, int centerX, int centerZ, int radius, RandomSource random) {
        int depth = 5 + random.nextInt(10);
        for (int dx = -radius; dx <= radius; dx++) {
            for (int dz = -radius; dz <= radius; dz++) {
                double distance = Math.sqrt(dx * dx + dz * dz) / radius;
                if (distance > 1.0) {
                    continue;
                }

                int x = centerX + dx;
                int z = centerZ + dz;
                int localSurface = KarstFeatureSupport.surfaceY(level, x, z);
                int localDepth = Mth.clamp((int)((1.0 - distance) * depth) + random.nextInt(2), 1, depth);
                int floorY = localSurface - localDepth;

                for (int y = localSurface; y > floorY; y--) {
                    BlockPos pos = new BlockPos(x, y, z);
                    if (level.getBlockState(pos).isAir()) {
                        continue;
                    }
                    KarstFeatureSupport.setIfWritable(level, origin, pos, Blocks.CAVE_AIR.defaultBlockState());
                }

                for (int y = floorY; y >= floorY - 2; y--) {
                    BlockPos pos = new BlockPos(x, y, z);
                    KarstFeatureSupport.replaceIfKarst(level, origin, pos, KarstFeatureSupport.limestoneShellState(x, y, z));
                }

                if (distance > 0.72) {
                    BlockPos rim = new BlockPos(x, localSurface, z);
                    KarstFeatureSupport.replaceIfKarst(level, origin, rim, KarstTerrain.WEATHERED_LIMESTONE.get().defaultBlockState());
                }
            }
        }
    }

    private static void exposeKarstPavement(WorldGenLevel level, BlockPos origin, int centerX, int centerZ, int radius, RandomSource random) {
        for (int dx = -radius; dx <= radius; dx++) {
            for (int dz = -radius; dz <= radius; dz++) {
                double distance = Math.sqrt(dx * dx + dz * dz) / radius;
                if (distance > 1.0 || random.nextFloat() < distance * 0.35F) {
                    continue;
                }

                int x = centerX + dx;
                int z = centerZ + dz;
                int localSurface = KarstFeatureSupport.surfaceY(level, x, z);
                int weatherDepth = 1 + random.nextInt(3);
                for (int y = localSurface; y >= localSurface - weatherDepth; y--) {
                    BlockPos pos = new BlockPos(x, y, z);
                    KarstFeatureSupport.replaceIfKarst(level, origin, pos, KarstFeatureSupport.limestoneShellState(x, y, z));
                }
            }
        }
    }

    private static void shapeKarstRelief(WorldGenLevel level, BlockPos origin, int centerX, int centerZ, int radius, double trend, RandomSource random) {
        for (int dx = -radius; dx <= radius; dx++) {
            for (int dz = -radius; dz <= radius; dz++) {
                double distance = Math.sqrt(dx * dx + dz * dz) / radius;
                if (distance > 1.0) {
                    continue;
                }

                int x = centerX + dx;
                int z = centerZ + dz;
                int surfaceY = KarstFeatureSupport.surfaceY(level, x, z);
                double along = dx * Math.cos(trend) + dz * Math.sin(trend);
                double terrace = Math.sin(along * 0.85);
                int lift = terrace > 0.55 && distance > 0.42 ? 1 + random.nextInt(2) : 0;

                for (int y = surfaceY; y >= surfaceY - 2; y--) {
                    BlockPos pos = new BlockPos(x, y, z);
                    KarstFeatureSupport.replaceIfKarst(level, origin, pos, KarstFeatureSupport.limestoneShellState(x, y, z));
                }

                for (int y = surfaceY + 1; y <= surfaceY + lift; y++) {
                    BlockPos pos = new BlockPos(x, y, z);
                    if (level.getBlockState(pos).isAir()) {
                        KarstFeatureSupport.setIfWritable(level, origin, pos, KarstFeatureSupport.limestoneShellState(x, y, z));
                    }
                }
            }
        }
    }

    private static void carveSurfaceFissures(WorldGenLevel level, BlockPos origin, int centerX, int centerZ, int radius, double trend, RandomSource random) {
        int fissures = 1 + random.nextInt(3);
        for (int i = 0; i < fissures; i++) {
            double angle = trend + (random.nextDouble() - 0.5) * 0.75;
            double x = centerX + random.nextInt(5) - 2;
            double z = centerZ + random.nextInt(5) - 2;
            int length = radius + 2 + random.nextInt(6);

            for (int step = 0; step < length; step++) {
                angle += (random.nextDouble() - 0.5) * 0.28;
                x += Math.cos(angle);
                z += Math.sin(angle);
                int ix = Mth.floor(x);
                int iz = Mth.floor(z);
                int surfaceY = KarstFeatureSupport.surfaceY(level, ix, iz);
                int width = random.nextInt(4) == 0 ? 1 : 0;
                int depth = 3 + random.nextInt(7);

                for (int dx = -width; dx <= width; dx++) {
                    for (int dz = -width; dz <= width; dz++) {
                        if (Math.abs(dx) + Math.abs(dz) > 1) {
                            continue;
                        }
                        for (int y = surfaceY; y > surfaceY - depth; y--) {
                            BlockPos pos = new BlockPos(ix + dx, y, iz + dz);
                            if (KarstFeatureSupport.canCarve(level.getBlockState(pos))) {
                                KarstFeatureSupport.setIfWritable(level, origin, pos, Blocks.CAVE_AIR.defaultBlockState());
                            }
                        }
                        BlockPos wall = new BlockPos(ix + dx, surfaceY - depth, iz + dz);
                        KarstFeatureSupport.replaceIfKarst(level, origin, wall, KarstFeatureSupport.limestoneShellState(wall.getX(), wall.getY(), wall.getZ()));
                    }
                }
            }
        }
    }
}
