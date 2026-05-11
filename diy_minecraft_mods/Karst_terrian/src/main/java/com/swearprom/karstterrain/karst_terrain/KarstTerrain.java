package com.swearprom.karstterrain.karst_terrain;

import org.slf4j.Logger;

import com.mojang.logging.LogUtils;
import com.swearprom.karstterrain.karst_terrain.worldgen.KarstFeatures;
import com.swearprom.karstterrain.karst_terrain.worldgen.KarstOverworldRegion;
import com.swearprom.karstterrain.karst_terrain.worldgen.KarstSurfaceRuleData;

import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;
import net.neoforged.fml.config.ModConfig;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.event.lifecycle.FMLCommonSetupEvent;
import net.neoforged.neoforge.event.BuildCreativeModeTabContentsEvent;
import net.neoforged.neoforge.registries.DeferredBlock;
import net.neoforged.neoforge.registries.DeferredHolder;
import net.neoforged.neoforge.registries.DeferredItem;
import net.neoforged.neoforge.registries.DeferredRegister;
import terrablender.api.Regions;
import terrablender.api.SurfaceRuleManager;

@Mod(KarstTerrain.MODID)
public class KarstTerrain {
    public static final String MODID = "karst_terrain";
    public static final Logger LOGGER = LogUtils.getLogger();

    public static final DeferredRegister.Blocks BLOCKS = DeferredRegister.createBlocks(MODID);
    public static final DeferredRegister.Items ITEMS = DeferredRegister.createItems(MODID);
    public static final DeferredRegister<CreativeModeTab> CREATIVE_MODE_TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, MODID);

    public static final DeferredBlock<Block> LIMESTONE = BLOCKS.registerSimpleBlock(
            "limestone",
            BlockBehaviour.Properties.of()
                    .mapColor(MapColor.TERRACOTTA_WHITE)
                    .strength(1.5F, 6.0F)
                    .requiresCorrectToolForDrops()
                    .sound(SoundType.STONE));
    public static final DeferredItem<BlockItem> LIMESTONE_ITEM = ITEMS.registerSimpleBlockItem("limestone", LIMESTONE);

    public static final DeferredBlock<Block> WEATHERED_LIMESTONE = BLOCKS.registerSimpleBlock(
            "weathered_limestone",
            BlockBehaviour.Properties.of()
                    .mapColor(MapColor.COLOR_LIGHT_GRAY)
                    .strength(1.4F, 6.0F)
                    .requiresCorrectToolForDrops()
                    .sound(SoundType.STONE));
    public static final DeferredItem<BlockItem> WEATHERED_LIMESTONE_ITEM = ITEMS.registerSimpleBlockItem("weathered_limestone", WEATHERED_LIMESTONE);

    public static final DeferredHolder<CreativeModeTab, CreativeModeTab> KARST_TAB = CREATIVE_MODE_TABS.register("karst_terrain", () -> CreativeModeTab.builder()
            .title(Component.translatable("itemGroup.karst_terrain"))
            .withTabsBefore(CreativeModeTabs.BUILDING_BLOCKS)
            .icon(() -> LIMESTONE_ITEM.get().getDefaultInstance())
            .displayItems((parameters, output) -> {
                output.accept(LIMESTONE_ITEM.get());
                output.accept(WEATHERED_LIMESTONE_ITEM.get());
            }).build());

    public KarstTerrain(IEventBus modEventBus, ModContainer modContainer) {
        modEventBus.addListener(this::commonSetup);
        modEventBus.addListener(this::addCreative);

        BLOCKS.register(modEventBus);
        ITEMS.register(modEventBus);
        CREATIVE_MODE_TABS.register(modEventBus);
        KarstFeatures.FEATURES.register(modEventBus);

        modContainer.registerConfig(ModConfig.Type.COMMON, Config.SPEC);
    }

    private void commonSetup(FMLCommonSetupEvent event) {
        event.enqueueWork(() -> {
            Regions.register(new KarstOverworldRegion(ResourceLocation.fromNamespaceAndPath(MODID, "overworld_karst"), 4));
            SurfaceRuleManager.addSurfaceRules(SurfaceRuleManager.RuleCategory.OVERWORLD, MODID, KarstSurfaceRuleData.makeRules());
        });
        LOGGER.info("Karst Terrain loaded. Karst Highlands is registered for Overworld generation.");
    }

    private void addCreative(BuildCreativeModeTabContentsEvent event) {
        if (event.getTabKey() == CreativeModeTabs.BUILDING_BLOCKS) {
            event.accept(LIMESTONE_ITEM);
            event.accept(WEATHERED_LIMESTONE_ITEM);
        }
    }
}
