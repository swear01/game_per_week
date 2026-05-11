package com.swearprom.karstterrain.karst_terrain.worldgen;

import com.swearprom.karstterrain.karst_terrain.KarstTerrain;

import net.minecraft.core.BlockPos;
import net.minecraft.tags.BlockTags;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.levelgen.Heightmap;

final class KarstFeatureSupport {
    private KarstFeatureSupport() {
    }

    static int surfaceY(WorldGenLevel level, int x, int z) {
        return level.getHeight(Heightmap.Types.WORLD_SURFACE_WG, x, z) - 1;
    }

    static boolean canReplaceForKarst(BlockState state) {
        return !state.isAir()
                && !state.liquid()
                && !state.is(BlockTags.FEATURES_CANNOT_REPLACE)
                && (state.is(BlockTags.BASE_STONE_OVERWORLD)
                        || state.is(BlockTags.STONE_ORE_REPLACEABLES)
                        || state.is(BlockTags.DIRT)
                        || state.is(Blocks.GRASS_BLOCK)
                        || state.is(Blocks.GRAVEL)
                        || state.is(Blocks.SAND)
                        || state.is(KarstTerrain.LIMESTONE.get())
                        || state.is(KarstTerrain.WEATHERED_LIMESTONE.get()));
    }

    static boolean canCarve(BlockState state) {
        return canReplaceForKarst(state) || state.is(KarstTerrain.LIMESTONE.get()) || state.is(KarstTerrain.WEATHERED_LIMESTONE.get());
    }

    static boolean isSolidSupport(WorldGenLevel level, BlockPos pos) {
        BlockState state = level.getBlockState(pos);
        return !state.isAir() && !state.liquid();
    }

    static void setIfWritable(WorldGenLevel level, BlockPos pos, BlockState state) {
        if (!level.isOutsideBuildHeight(pos) && level.ensureCanWrite(pos)) {
            level.setBlock(pos, state, 2);
        }
    }

    static void setIfWritable(WorldGenLevel level, BlockPos origin, BlockPos pos, BlockState state) {
        if (isInsideOriginChunk(origin, pos)) {
            setIfWritable(level, pos, state);
        }
    }

    static void replaceIfKarst(WorldGenLevel level, BlockPos pos, BlockState state) {
        if (!level.isOutsideBuildHeight(pos) && level.ensureCanWrite(pos) && canReplaceForKarst(level.getBlockState(pos))) {
            level.setBlock(pos, state, 2);
        }
    }

    static void replaceIfKarst(WorldGenLevel level, BlockPos origin, BlockPos pos, BlockState state) {
        if (isInsideOriginChunk(origin, pos)) {
            replaceIfKarst(level, pos, state);
        }
    }

    static boolean isInsideOriginChunk(BlockPos origin, BlockPos pos) {
        int minX = origin.getX() & ~15;
        int minZ = origin.getZ() & ~15;
        return pos.getX() >= minX && pos.getX() <= minX + 15 && pos.getZ() >= minZ && pos.getZ() <= minZ + 15;
    }

    static BlockState limestoneShellState(int x, int y, int z) {
        int hash = Math.abs(x * 73428767 ^ y * 912931 ^ z * 42349);
        return hash % 5 == 0 ? KarstTerrain.WEATHERED_LIMESTONE.get().defaultBlockState() : KarstTerrain.LIMESTONE.get().defaultBlockState();
    }
}
