using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public static class Builder
{
    static readonly string[] Designs = { "classic", "rainbow", "tiger", "navy" };

    // Unity -batchmode -quit -projectPath OceanBaby -executeMethod Builder.Build
    public static void Build()
    {
        SetupAssets();

        var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
        EditorSceneManager.SaveScene(scene, "Assets/Main.unity");

        PlayerSettings.productName = "OceanBaby";
        PlayerSettings.fullScreenMode = FullScreenMode.Windowed;
        PlayerSettings.defaultScreenWidth = 1440;
        PlayerSettings.defaultScreenHeight = 900;
        PlayerSettings.resizableWindow = true;
        PlayerSettings.SplashScreen.show = false;
        PlayerSettings.runInBackground = true;
        PlayerSettings.enableFrameTimingStats = true; // 自我檢查時量 CPU / GPU 時間
        // IL2CPP：C# 編成原生碼，暴力掃三十萬條飄帶快好幾倍；只出 Apple Silicon 版
        var standalone = UnityEditor.Build.NamedBuildTarget.Standalone;
        PlayerSettings.SetScriptingBackend(standalone, ScriptingImplementation.IL2CPP);
        PlayerSettings.SetIl2CppCompilerConfiguration(standalone, Il2CppCompilerConfiguration.Release);
        PlayerSettings.SetIl2CppCodeGeneration(standalone, UnityEditor.Build.Il2CppCodeGeneration.OptimizeSpeed);
        UnityEditor.OSXStandalone.UserBuildSettings.architecture = UnityEditor.Build.OSArchitecture.ARM64;
        PlayerSettings.SetManagedStrippingLevel(standalone, ManagedStrippingLevel.High); // 用不到的 .NET／引擎程式碼砍掉，包小一點

        var report = BuildPipeline.BuildPlayer(new[] { "Assets/Main.unity" }, "Build/OceanBaby.app", BuildTarget.StandaloneOSX, BuildOptions.None);
        Debug.Log("BUILD RESULT: " + report.summary.result);
        if (report.summary.result != BuildResult.Succeeded) EditorApplication.Exit(1);
    }

    // 發佈版：Mac 分 Apple Silicon／Intel 兩包（各只帶一種架構，下載小一半），Windows 64 位元（Mac 上不能交叉編 IL2CPP，用 Mono；DX12 優先、不支援的顯卡退回 DX11）
    // Unity -batchmode -quit -projectPath OceanBaby -executeMethod Builder.BuildRelease
    public static void BuildRelease()
    {
        Build(); // 場景、資源、共用設定
        if (Directory.Exists("Release")) Directory.Delete("Release", true);
        var standalone = UnityEditor.Build.NamedBuildTarget.Standalone;
        bool ok = true;
        foreach (var (dir, arch) in new[] { ("mac", UnityEditor.Build.OSArchitecture.ARM64), ("mac-intel", UnityEditor.Build.OSArchitecture.x64) })
        {
            UnityEditor.OSXStandalone.UserBuildSettings.architecture = arch;
            var r = BuildPipeline.BuildPlayer(new[] { "Assets/Main.unity" }, $"Release/{dir}/OceanBaby.app", BuildTarget.StandaloneOSX, BuildOptions.None);
            Debug.Log($"RELEASE {dir}: " + r.summary.result);
            ok &= r.summary.result == BuildResult.Succeeded;
        }
        UnityEditor.OSXStandalone.UserBuildSettings.architecture = UnityEditor.Build.OSArchitecture.ARM64;
        PlayerSettings.SetScriptingBackend(standalone, ScriptingImplementation.Mono2x);
        PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.StandaloneWindows64, false);
        PlayerSettings.SetGraphicsAPIs(BuildTarget.StandaloneWindows64, new[] { GraphicsDeviceType.Direct3D12, GraphicsDeviceType.Direct3D11 });
        var win = BuildPipeline.BuildPlayer(new[] { "Assets/Main.unity" }, "Release/win/OceanBaby.exe", BuildTarget.StandaloneWindows64, BuildOptions.None);
        Debug.Log("RELEASE win: " + win.summary.result);
        ok &= win.summary.result == BuildResult.Succeeded;
        PlayerSettings.SetScriptingBackend(standalone, ScriptingImplementation.IL2CPP);
        EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Standalone, BuildTarget.StandaloneOSX);
        if (!ok) EditorApplication.Exit(1);
    }

    // 瀏覽器版：WebGPU（飄帶 shader 要 StructuredBuffer，WebGL2 沒有）；gzip + fallback，itch 和一般靜態伺服器都能載
    // Unity -batchmode -quit -projectPath OceanBaby -executeMethod Builder.BuildWeb
    public static void BuildWeb()
    {
        Build();
        EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.WebGL, BuildTarget.WebGL);
        PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.WebGL, false);
        PlayerSettings.SetGraphicsAPIs(BuildTarget.WebGL, new[] { GraphicsDeviceType.WebGPU });
        PlayerSettings.WebGL.compressionFormat = WebGLCompressionFormat.Gzip;
        PlayerSettings.WebGL.decompressionFallback = true;
        PlayerSettings.WebGL.maximumMemorySize = 2048;
        var web = BuildPipeline.BuildPlayer(new[] { "Assets/Main.unity" }, "Release/web", BuildTarget.WebGL, BuildOptions.None);
        Debug.Log("RELEASE web: " + web.summary.result);
        // 效能優先：Retina／高 DPI 螢幕也只畫 1 倍解析度，GPU 要畫的像素少四倍
        // 剛按 Esc 就點畫面時瀏覽器會拒絕鎖滑鼠；Unity 預設把它當當機跳 alert，其實再點一次就好，所以忽略
        const string html = "Release/web/index.html", hook = "      var script = document.createElement(\"script\");";
        if (File.Exists(html)) File.WriteAllText(html, File.ReadAllText(html).Replace(hook,
            "      config.devicePixelRatio = 1;\n      config.errorHandler = (msg) => /pointer lock/i.test(msg);\n" + hook));
        EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Standalone, BuildTarget.StandaloneOSX);
        if (web.summary.result != BuildResult.Succeeded) EditorApplication.Exit(1);
    }

    // URP 管線 + 每種飄帶一個開 GPU instancing 的材質（放 Resources，執行時載入）
    [MenuItem("OceanBaby/Setup Assets")]
    public static void SetupAssets()
    {
        Directory.CreateDirectory("Assets/Settings");
        Directory.CreateDirectory("Assets/Resources/Mats");
        AssetDatabase.Refresh();

        const string urpPath = "Assets/Settings/URP.asset";
        var urp = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(urpPath);
        if (urp == null)
        {
            var data = ScriptableObject.CreateInstance<UniversalRendererData>();
            AssetDatabase.CreateAsset(data, "Assets/Settings/URP_Renderer.asset");
            urp = UniversalRenderPipelineAsset.Create(data);
            AssetDatabase.CreateAsset(urp, urpPath);
        }
        urp.shadowDistance = 22; urp.shadowCascadeCount = 1; urp.supportsHDR = true; // 陰影一層就好；HDR 保留，畫面效果不降
        GraphicsSettings.defaultRenderPipeline = urp;
        for (int i = 0; i < QualitySettings.names.Length; i++)
        {
            QualitySettings.SetQualityLevel(i, false);
            QualitySettings.renderPipeline = urp;
        }

        var lit = Shader.Find("Universal Render Pipeline/Lit");
        var rib = Shader.Find("OceanBaby/RibbonInstanced");
        foreach (var d in Designs)
        {
            // 貼圖：各向異性過濾 + 稍微偏銳的 mipmap，斜看「2026 台北 洋流」小字才不會糊
            string tp = $"Assets/Resources/Ribbons/{d}.png";
            var ti = (TextureImporter)AssetImporter.GetAtPath(tp);
            ti.anisoLevel = 16; ti.filterMode = FilterMode.Trilinear; ti.mipMapBias = -0.5f; ti.maxTextureSize = 4096;
            ti.SaveAndReimport();

            // 飄帶本體：GPU buffer 版 shader
            string rp = $"Assets/Resources/Mats/rib_{d}.mat";
            var rm = AssetDatabase.LoadAssetAtPath<Material>(rp);
            if (rm == null) { rm = new Material(rib); AssetDatabase.CreateAsset(rm, rp); }
            rm.shader = rib;
            rm.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>(tp));
            rm.SetTextureScale("_BaseMap", new Vector2(1, 2.2f)); // 1.6m 長、9cm 寬，貼圖 1:8 → 一張約 0.72m
            EditorUtility.SetDirty(rm);

            string path = $"Assets/Resources/Mats/{d}.mat";
            var m = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (m == null) { m = new Material(lit); AssetDatabase.CreateAsset(m, path); }
            m.shader = lit;
            m.enableInstancing = true;
            m.SetTexture("_BaseMap", AssetDatabase.LoadAssetAtPath<Texture2D>($"Assets/Resources/Ribbons/{d}.png"));
            m.SetTextureScale("_BaseMap", new Vector2(1, 2.2f));
            m.SetFloat("_Smoothness", 0.3f); // Lit 版只給地面和奶龍的眼睛當底
            EditorUtility.SetDirty(m);
        }
        // 奶龍身體：Particles/Lit 會乘頂點色，一張網格就能畫出肚子、嘴巴、爪的漸層
        const string nlPath = "Assets/Resources/Mats/nailong.mat";
        var pl = Shader.Find("Universal Render Pipeline/Particles/Lit");
        var nl = AssetDatabase.LoadAssetAtPath<Material>(nlPath);
        if (nl == null) { nl = new Material(pl); AssetDatabase.CreateAsset(nl, nlPath); }
        nl.shader = pl;
        nl.SetColor("_BaseColor", Color.white);
        nl.SetFloat("_Smoothness", 0.3f);
        EditorUtility.SetDirty(nl);
        AssetDatabase.SaveAssets();
    }
}
