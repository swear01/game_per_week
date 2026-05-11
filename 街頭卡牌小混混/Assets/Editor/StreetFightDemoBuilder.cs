using System.IO;
using StreetCardBrawler.Cards;
using StreetCardBrawler.Combat;
using UnityEditor;
using UnityEditor.Events;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace StreetCardBrawler.Editor
{
    public static class StreetFightDemoBuilder
    {
        private static Sprite squareSprite;
        private static Font font;

        [MenuItem("Street Card Brawler/Build Demo Scene")]
        public static void Build()
        {
            Directory.CreateDirectory("Assets/Scenes");
            Directory.CreateDirectory("Assets/Art");
            Directory.CreateDirectory("Assets/Data/Cards");

            squareSprite = EnsureSquareSprite();
            font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            if (font == null) font = Resources.GetBuiltinResource<Font>("Arial.ttf");

            var jab = MakeCard("Jab", "Jab", "Quick close punch", CardEffectType.Damage, 1, 10, 1.55f, 0f, 0f, 0f, 0, 0f);
            var haymaker = MakeCard("Haymaker", "Haymaker", "Slow heavy hit", CardEffectType.Damage, 3, 28, 1.65f, 0.35f, 0f, 0f, 0, 0f);
            var block = MakeCard("Block", "Block", "Reduce incoming damage", CardEffectType.Block, 1, 0, 0f, 0f, 1.8f, 0f, 0, 0f);
            var dashKick = MakeCard("DashKick", "Dash Kick", "Lunge forward and strike", CardEffectType.DashDamage, 2, 18, 1.75f, 0.1f, 0f, 1.7f, 0, 0f);
            var taunt = MakeCard("Taunt", "Taunt", "Gain energy, anger enemy", CardEffectType.Taunt, 0, 0, 0f, 0f, 0f, 0f, 2, 3f);
            AssetDatabase.SaveAssets();

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            scene.name = "StreetFightDemo";

            var cameraGo = new GameObject("Main Camera");
            cameraGo.tag = "MainCamera";
            cameraGo.transform.position = new Vector3(0f, 1.2f, -10f);
            var camera = cameraGo.AddComponent<Camera>();
            camera.orthographic = true;
            camera.orthographicSize = 4.2f;
            camera.backgroundColor = new Color(0.09f, 0.1f, 0.12f, 1f);

            MakeSprite("Back Alley Wall", new Vector3(0f, 1.4f, 0f), new Vector3(15f, 5.2f, 1f), new Color(0.16f, 0.18f, 0.22f, 1f), -5);
            MakeSprite("Street Ground", new Vector3(0f, -2.15f, 0f), new Vector3(15f, 1.1f, 1f), new Color(0.08f, 0.08f, 0.075f, 1f), -4);
            MakeSprite("Graffiti Stripe", new Vector3(0f, 2.25f, 0f), new Vector3(12f, 0.25f, 1f), new Color(0.9f, 0.23f, 0.2f, 1f), -3);
            MakeSprite("Neon Sign", new Vector3(-4.8f, 2.8f, 0f), new Vector3(1.6f, 0.55f, 1f), new Color(0.1f, 0.8f, 0.95f, 1f), -2);

            var playerGo = MakeSprite("Player", new Vector3(-2.6f, -1.15f, 0f), new Vector3(0.85f, 1.55f, 1f), new Color(0.15f, 0.55f, 1f, 1f), 1);
            var playerRb = playerGo.AddComponent<Rigidbody2D>();
            playerRb.gravityScale = 0f;
            playerRb.constraints = RigidbodyConstraints2D.FreezeRotation | RigidbodyConstraints2D.FreezePositionY;
            playerGo.GetComponent<BoxCollider2D>().size = Vector2.one;
            var player = playerGo.AddComponent<PlayerFighter>();

            var enemyGo = MakeSprite("Street Thug", new Vector3(2.7f, -1.15f, 0f), new Vector3(0.9f, 1.6f, 1f), new Color(0.95f, 0.28f, 0.18f, 1f), 1);
            var enemyRb = enemyGo.AddComponent<Rigidbody2D>();
            enemyRb.gravityScale = 0f;
            enemyRb.constraints = RigidbodyConstraints2D.FreezeRotation | RigidbodyConstraints2D.FreezePositionY;
            enemyGo.GetComponent<BoxCollider2D>().size = Vector2.one;
            var enemy = enemyGo.AddComponent<EnemyFighter>();
            enemy.playerTarget = playerGo.transform;
            enemy.player = player;

            var systemsGo = new GameObject("Battle Systems");
            var deck = systemsGo.AddComponent<CardDeckController>();
            var resolver = systemsGo.AddComponent<CardEffectResolver>();
            var ui = systemsGo.AddComponent<BattleUIController>();

            deck.deck.Add(jab);
            deck.deck.Add(haymaker);
            deck.deck.Add(block);
            deck.deck.Add(dashKick);
            deck.deck.Add(taunt);
            deck.resolver = resolver;
            deck.ui = ui;
            resolver.player = player;
            resolver.enemy = enemy;
            resolver.ui = ui;
            player.deckController = deck;

            BuildHud(out var canvasGo, player, enemy, deck, ui);

            EditorSceneManager.SaveScene(scene, "Assets/Scenes/StreetFightDemo.unity");
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene("Assets/Scenes/StreetFightDemo.unity", true) };
            AssetDatabase.SaveAssets();
            Debug.Log("StreetFightDemo built with five card assets.");
        }

        private static Sprite EnsureSquareSprite()
        {
            const string spritePath = "Assets/Art/white_square.png";
            if (!File.Exists(spritePath))
            {
                var tex = new Texture2D(32, 32, TextureFormat.RGBA32, false);
                var pixels = new Color[32 * 32];
                for (int i = 0; i < pixels.Length; i++) pixels[i] = Color.white;
                tex.SetPixels(pixels);
                tex.Apply();
                File.WriteAllBytes(spritePath, tex.EncodeToPNG());
                AssetDatabase.ImportAsset(spritePath);
            }

            var importer = (TextureImporter)AssetImporter.GetAtPath(spritePath);
            importer.textureType = TextureImporterType.Sprite;
            importer.spriteImportMode = SpriteImportMode.Single;
            importer.spritePixelsPerUnit = 32f;
            importer.filterMode = FilterMode.Point;
            importer.SaveAndReimport();
            AssetDatabase.ImportAsset(spritePath, ImportAssetOptions.ForceUpdate);

            var directSprite = AssetDatabase.LoadAssetAtPath<Sprite>(spritePath);
            if (directSprite != null) return directSprite;

            foreach (var asset in AssetDatabase.LoadAllAssetsAtPath(spritePath))
            {
                if (asset is Sprite sprite)
                {
                    return sprite;
                }
            }

            Debug.LogError("Could not load generated square sprite.");
            return null;
        }

        private static CardData MakeCard(string assetName, string displayName, string description, CardEffectType type, int cost, int damage, float range, float windup, float blockDuration, float dashDistance, int energyGain, float tauntDuration)
        {
            string path = "Assets/Data/Cards/" + assetName + ".asset";
            var card = AssetDatabase.LoadAssetAtPath<CardData>(path);
            if (card == null)
            {
                card = ScriptableObject.CreateInstance<CardData>();
                AssetDatabase.CreateAsset(card, path);
            }

            card.cardName = displayName;
            card.description = description;
            card.effectType = type;
            card.energyCost = cost;
            card.damage = damage;
            card.range = range;
            card.windup = windup;
            card.blockDuration = blockDuration;
            card.blockMultiplier = 0.35f;
            card.dashDistance = dashDistance;
            card.energyGain = energyGain;
            card.tauntDuration = tauntDuration;
            EditorUtility.SetDirty(card);
            return card;
        }

        private static GameObject MakeSprite(string name, Vector3 position, Vector3 scale, Color color, int order)
        {
            var go = new GameObject(name);
            go.transform.position = position;
            go.transform.localScale = scale;
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sprite = squareSprite;
            sr.color = color;
            sr.sortingOrder = order;
            go.AddComponent<BoxCollider2D>();
            return go;
        }

        private static void BuildHud(out GameObject canvasParent, PlayerFighter player, EnemyFighter enemy, CardDeckController deck, BattleUIController ui)
        {
            canvasParent = new GameObject("HUD Canvas");
            var canvas = canvasParent.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            var scaler = canvasParent.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1280f, 720f);
            canvasParent.AddComponent<GraphicRaycaster>();

            var eventSystem = new GameObject("EventSystem");
            eventSystem.AddComponent<EventSystem>();
            eventSystem.AddComponent<StandaloneInputModule>();

            var topBar = MakeUI("Top Bar", canvasParent.transform, new Vector2(0f, 1f), new Vector2(1f, 1f), new Vector2(24f, -86f), new Vector2(-24f, -18f));
            topBar.AddComponent<Image>().color = new Color(0f, 0f, 0f, 0.55f);
            var playerHp = AddText(MakeUI("Player HP", topBar.transform, new Vector2(0f, 0f), new Vector2(0.32f, 1f), Vector2.zero, Vector2.zero), "Player HP", 26, TextAnchor.MiddleLeft, Color.white);
            var energyText = AddText(MakeUI("Energy", topBar.transform, new Vector2(0.34f, 0f), new Vector2(0.66f, 1f), Vector2.zero, Vector2.zero), "Energy", 26, TextAnchor.MiddleCenter, new Color(1f, 0.88f, 0.2f, 1f));
            var enemyHp = AddText(MakeUI("Enemy HP", topBar.transform, new Vector2(0.68f, 0f), new Vector2(1f, 1f), Vector2.zero, Vector2.zero), "Thug HP", 26, TextAnchor.MiddleRight, Color.white);

            var statusText = AddText(MakeUI("Status", canvasParent.transform, new Vector2(0.25f, 0.23f), new Vector2(0.75f, 0.33f), Vector2.zero, Vector2.zero), "", 26, TextAnchor.MiddleCenter, new Color(1f, 1f, 1f, 0.95f));
            var handPanel = MakeUI("Hand Panel", canvasParent.transform, new Vector2(0f, 0f), new Vector2(1f, 0f), new Vector2(24f, 24f), new Vector2(-24f, 154f));
            handPanel.AddComponent<Image>().color = new Color(0.02f, 0.02f, 0.025f, 0.82f);

            var buttons = new Button[3];
            var labels = new Text[3];
            for (int i = 0; i < 3; i++)
            {
                float start = 0.04f + i * 0.32f;
                var buttonGo = MakeUI("Card " + (i + 1), handPanel.transform, new Vector2(start, 0.12f), new Vector2(start + 0.28f, 0.88f), Vector2.zero, Vector2.zero);
                buttonGo.AddComponent<Image>().color = new Color(0.92f, 0.86f, 0.72f, 1f);
                var button = buttonGo.AddComponent<Button>();
                var binder = buttonGo.AddComponent<CardButtonBinder>();
                binder.deck = deck;
                binder.handIndex = i;
                UnityEventTools.AddPersistentListener(button.onClick, binder.Play);
                labels[i] = AddText(MakeUI("Label", buttonGo.transform, Vector2.zero, Vector2.one, new Vector2(10f, 6f), new Vector2(-10f, -6f)), "Card", 20, TextAnchor.MiddleCenter, Color.black);
                buttons[i] = button;
            }

            var endPanel = MakeUI("End Panel", canvasParent.transform, new Vector2(0.32f, 0.36f), new Vector2(0.68f, 0.64f), Vector2.zero, Vector2.zero);
            endPanel.AddComponent<Image>().color = new Color(0f, 0f, 0f, 0.82f);
            var endText = AddText(MakeUI("End Text", endPanel.transform, Vector2.zero, Vector2.one, Vector2.zero, Vector2.zero), "Victory", 36, TextAnchor.MiddleCenter, Color.white);
            endPanel.SetActive(false);

            ui.player = player;
            ui.enemy = enemy;
            ui.deck = deck;
            ui.playerHealthText = playerHp;
            ui.enemyHealthText = enemyHp;
            ui.energyText = energyText;
            ui.statusText = statusText;
            ui.endPanel = endPanel;
            ui.endText = endText;
            ui.cardButtons = buttons;
            ui.cardLabels = labels;
        }

        private static GameObject MakeUI(string name, Transform parent, Vector2 anchorMin, Vector2 anchorMax, Vector2 offsetMin, Vector2 offsetMax)
        {
            var go = new GameObject(name, typeof(RectTransform));
            go.transform.SetParent(parent, false);
            var rt = go.GetComponent<RectTransform>();
            rt.anchorMin = anchorMin;
            rt.anchorMax = anchorMax;
            rt.offsetMin = offsetMin;
            rt.offsetMax = offsetMax;
            return go;
        }

        private static Text AddText(GameObject go, string value, int size, TextAnchor anchor, Color color)
        {
            var text = go.AddComponent<Text>();
            text.font = font;
            text.text = value;
            text.fontSize = size;
            text.alignment = anchor;
            text.color = color;
            text.raycastTarget = false;
            return text;
        }
    }
}
