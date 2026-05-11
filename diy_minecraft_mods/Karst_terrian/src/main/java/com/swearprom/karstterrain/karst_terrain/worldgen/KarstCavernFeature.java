package com.swearprom.karstterrain.karst_terrain.worldgen;

import com.mojang.serialization.Codec;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.PointedDripstoneBlock;
import net.minecraft.world.level.block.state.properties.DripstoneThickness;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.FeaturePlaceContext;
import net.minecraft.world.level.levelgen.feature.configurations.NoneFeatureConfiguration;

public class KarstCavernFeature extends Feature<NoneFeatureConfiguration> {
    public KarstCavernFeature(Codec<NoneFeatureConfiguration> codec) {
        super(codec);
    }

    @Override
    public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> context) {
        WorldGenLevel level = context.level();
        RandomSource random = context.random();
        BlockPos origin = context.origin();
        int surfaceY = KarstFeatureSupport.surfaceY(level, origin.getX(), origin.getZ());
        int centerY = Math.min(origin.getY(), surfaceY - 12);
        if (centerY < 18 || centerY > 118) {
            return false;
        }

        int radiusX = 8 + random.nextInt(6);
        int radiusY = 5 + random.nextInt(4);
        int radiusZ = 8 + random.nextInt(6);
        BlockPos center = new BlockPos(origin.getX(), centerY, origin.getZ());
        int carved = carveCavern(level, origin, center, radiusX, radiusY, radiusZ, random);
        if (carved < 80) {
            return false;
        }

        lineCavernShell(level, origin, center, radiusX, radiusY, radiusZ);
        decorateDripstone(level, origin, center, radiusX, radiusY, radiusZ, random);
        return true;
    }

    private static int carveCavern(WorldGenLevel level, BlockPos origin, BlockPos center, int radiusX, int radiusY, int radiusZ, RandomSource random) {
        int carved = 0;
        int waterY = center.getY() - radiusY + 1;
        for (int dx = -radiusX; dx <= radiusX; dx++) {
            for (int dy = -radiusY; dy <= radiusY; dy++) {
                for (int dz = -radiusZ; dz <= radiusZ; dz++) {
                    double value = (dx * dx) / (double)(radiusX * radiusX)
                            + (dy * dy) / (double)(radiusY * radiusY)
                            + (dz * dz) / (double)(radiusZ * radiusZ);
                    if (value > 1.0 + random.nextDouble() * 0.08) {
                        continue;
                    }

                    BlockPos pos = center.offset(dx, dy, dz);
                    if (!KarstFeatureSupport.canCarve(level.getBlockState(pos))) {
                        continue;
                    }

                    KarstFeatureSupport.setIfWritable(level, origin, pos, pos.getY() <= waterY
                            ? Blocks.WATER.defaultBlockState()
                            : Blocks.CAVE_AIR.defaultBlockState());
                    carved++;
                }
            }
        }
        return carved;
    }

    private static void lineCavernShell(WorldGenLevel level, BlockPos origin, BlockPos center, int radiusX, int radiusY, int radiusZ) {
        for (int dx = -radiusX - 1; dx <= radiusX + 1; dx++) {
            for (int dy = -radiusY - 1; dy <= radiusY + 1; dy++) {
                for (int dz = -radiusZ - 1; dz <= radiusZ + 1; dz++) {
                    double value = (dx * dx) / (double)(radiusX * radiusX)
                            + (dy * dy) / (double)(radiusY * radiusY)
                            + (dz * dz) / (double)(radiusZ * radiusZ);
                    if (value < 1.0 || value > 1.34) {
                        continue;
                    }

                    BlockPos pos = center.offset(dx, dy, dz);
                    KarstFeatureSupport.replaceIfKarst(level, origin, pos, KarstFeatureSupport.limestoneShellState(pos.getX(), pos.getY(), pos.getZ()));
                }
            }
        }
    }

    private static void decorateDripstone(WorldGenLevel level, BlockPos origin, BlockPos center, int radiusX, int radiusY, int radiusZ, RandomSource random) {
        int attempts = 16 + random.nextInt(12);
        for (int i = 0; i < attempts; i++) {
            int x = center.getX() + random.nextInt(radiusX * 2 + 1) - radiusX;
            int z = center.getZ() + random.nextInt(radiusZ * 2 + 1) - radiusZ;
            int floorY = findFloor(level, x, center.getY(), z, radiusY + 2);
            int ceilingY = findCeiling(level, x, center.getY(), z, radiusY + 2);
            if (floorY != Integer.MIN_VALUE && random.nextBoolean()) {
                placePointed(level, origin, new BlockPos(x, floorY + 1, z), Direction.UP);
            }
            if (ceilingY != Integer.MIN_VALUE && random.nextInt(3) == 0) {
                placePointed(level, origin, new BlockPos(x, ceilingY - 1, z), Direction.DOWN);
            }
        }
    }

    private static int findFloor(WorldGenLevel level, int x, int centerY, int z, int range) {
        for (int y = centerY; y >= centerY - range; y--) {
            BlockPos air = new BlockPos(x, y, z);
            if (level.getBlockState(air).isAir() && KarstFeatureSupport.isSolidSupport(level, air.below())) {
                return y - 1;
            }
        }
        return Integer.MIN_VALUE;
    }

    private static int findCeiling(WorldGenLevel level, int x, int centerY, int z, int range) {
        for (int y = centerY; y <= centerY + range; y++) {
            BlockPos air = new BlockPos(x, y, z);
            if (level.getBlockState(air).isAir() && KarstFeatureSupport.isSolidSupport(level, air.above())) {
                return y + 1;
            }
        }
        return Integer.MIN_VALUE;
    }

    private static void placePointed(WorldGenLevel level, BlockPos origin, BlockPos pos, Direction direction) {
        if (!level.getBlockState(pos).isAir()) {
            return;
        }
        KarstFeatureSupport.setIfWritable(level, origin, direction == Direction.UP ? pos.below() : pos.above(), Blocks.DRIPSTONE_BLOCK.defaultBlockState());
        KarstFeatureSupport.setIfWritable(level, origin, pos, Blocks.POINTED_DRIPSTONE.defaultBlockState()
                .setValue(PointedDripstoneBlock.TIP_DIRECTION, direction)
                .setValue(PointedDripstoneBlock.THICKNESS, DripstoneThickness.TIP)
                .setValue(PointedDripstoneBlock.WATERLOGGED, Boolean.FALSE));
    }
}
