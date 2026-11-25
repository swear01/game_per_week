using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// 三十萬條洋流飄帶（9cm × 1.6m，軟的）堆成一座山，奶龍埋在裡面。玩家是小孩的視角（眼睛 1 公尺高）。
// 第一人稱拿吸塵器：WASD 走、空白鍵跳、滑鼠看、按住左鍵吸準心前的飄帶、C 蹲。
//
// 效能做法：
// 1. 飄帶矩陣放 GPU buffer，用自訂 shader 從 buffer 讀（RibbonInstanced.shader）；只有改變時才上傳，不是每幀上傳。
//    吸走／開始掉的飄帶只把它那一格清成 0；剛落地、剛露出來的先放每幀的小 buffer，最多每秒併回大 buffer 一次。
// 2. 埋在深處、四周塞滿的飄帶看不到，不畫。
// 3. 一張 10cm 體素格記每格有幾個飄帶取樣點：玩家當地面和牆、飄帶判斷有沒有被撐住、判斷看不看得到都用它。
public class PileGame : MonoBehaviour
{
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot()
    {
        Spawn();
        UnityEngine.SceneManagement.SceneManager.sceneLoaded += (_, _) => Spawn(); // 按 R 重玩會重新載入場景，要再生一次
    }
    static void Spawn() => new GameObject("PileGame").AddComponent<PileGame>();
    static int boots; // 自我檢查用：第二次啟動 = 重玩成功

    const int N = 300_000, OnGround = 1_500;    // 最後 OnGround 條是山腳零星滑落的，其餘全部堆在山上
    const int Shapes = 12, DrapeFrom = 8;       // 0-7 皺皺的、8-11 掛著垂下來的
    const float PileR = 5.9f, PileH = 3.4f, HalfLen = 0.8f, HalfW = 0.045f, HitRad = 0.06f;
    const int MaxFly = 2500, DynCap = 16384;
    const float Reach = 5f;
    static readonly string[] Designs = { "classic", "rainbow", "tiger", "navy" };

    // 吸力升級：Lv1 一次一條慢慢吸，越升級吸得越大團、越快
    // 一局約 3 分鐘：一開始 1 秒吸一條，最快 0.25 秒一次、半徑 35cm
    static readonly float[] SuckR = { 0, 0, 0.05f, 0.1f, 0.15f, 0.2f, 0.25f, 0.35f };
    static readonly float[] SuckEvery = { 1.0f, 0.7f, 0.6f, 0.5f, 0.4f, 0.3f, 0.25f, 0.25f };
    static readonly int[] SuckCost = { 0, 8, 25, 60, 300, 1000, 3000, 6000 }; // 依實測每吸一下的條數，每升一級約 20 秒

    Mesh[] meshes, shadowMeshes;                 // 陰影只要輪廓，用 3 段的低模，頂點少三分之二
    Mesh[][] lodMeshes;                          // [0] 10 段（5m 內）[1] 5 段（5-10m）[2] 3 段（10m 外）
    const int LodNearB = 10, LodMidB = 20;       // 以 0.5m 一層的距離桶計：5m、10m
    bool noLod;
    int G => Shapes * Designs.Length;

    // 每條飄帶
    Vector3[] segA, segB;
    Quaternion[] rot;
    Matrix4x4[] mtx;
    byte[] grp;
    bool[] alive, hidden, watched, isFalling, inExtra;
    float[] fallV;
    int[] slotOf;                                // 在大 buffer 的哪一格（-1 = 不在）
    int remaining;

    // GPU buffer：大堆（靜態）+ 每幀的小堆（正在掉、剛落地、剛露出來、被吸走的）
    GraphicsBuffer staticGB, dynGB;
    Matrix4x4[] staticCpu, dynCpu;
    int[] gOff, gCnt, dOff, dCnt;
    RenderParams[] sRp, dRp, shRp; int[] lodCnt;
    MaterialPropertyBlock[] shMpb, sMpb, dMpb;
    readonly List<int> extra = new();
    uint[] deadBits; GraphicsBuffer deadGB; int deadCount; bool deadDirty;
    bool rebuildNow; float nextRebuild;

    struct Fly { public int g; public Vector3 p, v, axis; public Quaternion q; public float spin, life; public bool burst; }  // 被吸走的飄帶；burst = 找到奶龍時噴出來的彩帶
    readonly List<Fly> flies = new();

    // 體素格：每格記有幾個飄帶取樣點
    const float Vox = 0.1f; const int GX = 182, GY = 44, GZ = 182, Samples = 17;
    static readonly Vector3 GridLo = new(-9.1f, 0, -9.1f);
    readonly short[] vox = new short[GX * GY * GZ];

    // 看不到的判斷：自己和上下左右前後 0.2m 都塞滿才算埋住
    const int HideThr = 14;
    static readonly Vector3[] Around = { Vector3.zero, new(0.2f, 0, 0), new(-0.2f, 0, 0), new(0, 0.2f, 0), new(0, -0.2f, 0), new(0, 0, 0.2f), new(0, 0, -0.2f) };

    // 重力：挖完後附近的飄帶如果底下空了就飄下來，躺平、垂掛在碰到的東西上
    const int SupportMin = 10, ChecksPerFrame = 3000;
    readonly List<int> watch = new(), falling = new();
    float watchUntil; int fell, watchCursor;

    // 玩家（小孩：眼睛 1m）。player 是腳底
    const float PR = 0.12f, StepH = 0.25f, StandH = 1.1f, CrouchH = 0.55f, StandEye = 1.0f, CrouchEye = 0.45f; const int Thr = 10;
    static readonly Vector2[] Ring = { new(0, 0), new(1, 0), new(-1, 0), new(0, 1), new(0, -1), new(0.7f, 0.7f), new(-0.7f, 0.7f), new(0.7f, -0.7f), new(-0.7f, -0.7f) };
    float vy, bodyH = StandH, stepOffset; bool grounded, noclip; Vector2 botMove; // botMove：自我檢查時代替鍵盤

    Transform baby, vac; Vector3 babyPos; const float BabyR = 0.2f; float kick;
    static readonly Vector3 VacPos = new(0.15f, -0.15f, 0.22f);
    Camera cam; Vector3 player = new(0, 0, -9f); float yaw, pitch = 8, eye = StandEye, standEye = StandEye;
    int coins, moved, suckLv;
    Font hudFont;
    float startTime, nextSuck, wonTime = -1;
    Rect panel;
    string shotPrefix;
    long winMs;

    void Start()
    {
        boots++;
        Application.targetFrameRate = 120;
        cam = Camera.main;
        cam.nearClipPlane = 0.02f; cam.fieldOfView = 60;
        var light = FindFirstObjectByType<Light>();
        if (light) { light.intensity = 1.3f; light.shadows = LightShadows.Soft; light.transform.rotation = Quaternion.Euler(55, -30, 0); }

        var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
        ground.transform.localScale = Vector3.one * 4;

        var rng = new System.Random();
        meshes = new Mesh[Shapes]; shadowMeshes = new Mesh[Shapes]; var mid = new Mesh[Shapes];
        for (int k = 0; k < Shapes; k++)
        {
            int seed = rng.Next();
            meshes[k] = RibbonMesh(new System.Random(seed), k >= DrapeFrom, 10);
            mid[k] = RibbonMesh(new System.Random(seed), k >= DrapeFrom, 5);
            shadowMeshes[k] = RibbonMesh(new System.Random(seed), k >= DrapeFrom, 3); // 同一個形狀，段數少
        }
        lodMeshes = new[] { meshes, mid, shadowMeshes };
        noLod = System.Array.IndexOf(System.Environment.GetCommandLineArgs(), "-nolod") >= 0; // 量效能時對照用

        babyPos = new Vector3(Rand(rng, -1.5f, 1.5f), BabyR, Rand(rng, -1.5f, 1.5f));
        var baseMat = Resources.Load<Material>("Mats/classic");
        ground.GetComponent<Renderer>().sharedMaterial = new Material(baseMat) { mainTexture = null, color = new Color(0.62f, 0.55f, 0.47f) };
        var args = System.Environment.GetCommandLineArgs();
        int pv = System.Array.IndexOf(args, "-preview");
        if (pv >= 0) babyPos = new Vector3(0, BabyR, -10f); // 擺到山外面拍照
        baby = Nailong.Build(baseMat).transform;
        baby.SetPositionAndRotation(babyPos, Quaternion.Euler(0, pv >= 0 ? 180 : Random.Range(0, 360), 0));
        BuildPile(rng);
        InitGrid();
        SetupGpu();
        RebuildStatic();

        vac = Vacuum.Build().transform;
        vac.SetParent(cam.transform, false);
        vac.localScale = Vector3.one * 0.75f;       // 小孩拿的大小
        vac.localPosition = VacPos;
        vac.localRotation = Quaternion.LookRotation(new Vector3(0, 0.02f, 2.5f) - VacPos); // 吸管指向準心前方
        if (pv >= 0) vac.gameObject.SetActive(false);

        int a = System.Array.IndexOf(args, "-shot");
        if (a < 0 && Application.platform == RuntimePlatform.WebGLPlayer && Application.absoluteURL.Contains("selfcheck")) { args = new[] { "-shot", "web" }; a = 0; } // 網頁版：網址加 ?selfcheck 跑同一套自我檢查
        if (a >= 0 && a + 1 < args.Length) { shotPrefix = args[a + 1]; StartCoroutine(SelfCheck()); }
        else if (pv >= 0 && pv + 1 < args.Length) { shotPrefix = args[pv + 1]; StartCoroutine(Preview()); }
        else Cursor.lockState = CursorLockMode.Locked;
        startTime = Time.time;
    }

    void OnDestroy()
    {
        staticGB?.Release(); dynGB?.Release(); deadGB?.Release();
        if (lodMeshes != null) foreach (var set in lodMeshes) foreach (var m in set) Destroy(m); // 按 R 重新載入場景時，執行時建的網格不會自己釋放
    }

    static float Rand(System.Random r, float lo, float hi) => lo + (float)r.NextDouble() * (hi - lo);

    // 軟飄帶：沿著法線方向起伏（像布一樣皺），drape 版中間高、兩端垂下來（掛在東西上）
    Mesh RibbonMesh(System.Random r, bool drape, int S)
    {
        float twist = Rand(r, -0.8f, 0.8f), lat = Rand(r, -0.04f, 0.04f);
        float a1 = Rand(r, -0.13f, 0.13f), f1 = Rand(r, 0.7f, 2f), p1 = Rand(r, 0, 6.28f);
        float a2 = Rand(r, -0.04f, 0.04f), f2 = Rand(r, 2.5f, 4f), p2 = Rand(r, 0, 6.28f);
        float arch = drape ? Rand(r, 0.3f, 0.55f) : 0;
        var v = new List<Vector3>(); var uv = new List<Vector2>(); var tri = new List<int>();
        for (int side = 0; side < 2; side++)    // 正反兩面各一份頂點，法線才不會打架
        {
            int b = v.Count;
            for (int i = 0; i <= S; i++)
            {
                float t = i / (float)S, th = twist * (t - 0.5f), u = 2 * t - 1;
                float y = a1 * Mathf.Sin(6.28f * f1 * t + p1) + a2 * Mathf.Sin(6.28f * f2 * t + p2) + arch * (0.5f - u * u);
                var c = new Vector3(lat * Mathf.Sin(3.14f * t), y, u * HalfLen);
                var w = new Vector3(Mathf.Cos(th), Mathf.Sin(th), 0) * HalfW;
                v.Add(c - w); v.Add(c + w);
                uv.Add(new Vector2(side, t)); uv.Add(new Vector2(1 - side, t));
                if (i == S) continue;
                int q = b + i * 2;
                if (side == 0) tri.AddRange(new[] { q, q + 2, q + 1, q + 1, q + 2, q + 3 });
                else tri.AddRange(new[] { q, q + 1, q + 2, q + 1, q + 3, q + 2 });
            }
        }
        var m = new Mesh(); m.SetVertices(v); m.SetUVs(0, uv); m.SetTriangles(tri, 0);
        m.RecalculateNormals(); m.RecalculateBounds();
        return m;
    }

    void BuildPile(System.Random r)
    {
        segA = new Vector3[N]; segB = new Vector3[N]; rot = new Quaternion[N]; mtx = new Matrix4x4[N]; grp = new byte[N];
        alive = new bool[N]; hidden = new bool[N]; watched = new bool[N]; isFalling = new bool[N]; inExtra = new bool[N];
        fallV = new float[N]; slotOf = new int[N];
        for (int i = 0; i < N;)
        {
            Vector3 p; Quaternion q;
            if (i < N - OnGround)
            {
                // 拋物面山丘裡均勻取點；軟飄帶大多是躺著、有點歪，不會一條條立著
                float x = Rand(r, -PileR, PileR), z = Rand(r, -PileR, PileR), y = Rand(r, 0.02f, PileH);
                float rr = (x * x + z * z) / (PileR * PileR);
                if (rr > 1 || y > PileH * Mathf.Pow(1 - rr, 0.8f) + 0.03f) continue;
                p = new Vector3(x, y, z);
                q = Quaternion.Euler(Rand(r, -20, 20), Rand(r, 0, 360), Rand(r, -50, 50) + r.Next(2) * 180);
            }
            else
            {
                // 山腳零星滑落的，緊貼山邊
                float ang = Rand(r, 0, 6.28f), rad = PileR + Mathf.Abs(Rand(r, -0.6f, 0.6f)) - 0.1f;
                p = new Vector3(Mathf.Cos(ang) * rad, 0.12f, Mathf.Sin(ang) * rad);
                q = Quaternion.Euler(0, Rand(r, 0, 360), Rand(r, -8, 8) + r.Next(2) * 180);
            }
            var dir = q * Vector3.forward * HalfLen;
            if (SegDist(babyPos, p - dir, p + dir) < BabyR + 0.06f) continue; // 奶龍身上留個空位
            segA[i] = p - dir; segB[i] = p + dir; rot[i] = q;
            mtx[i] = Matrix4x4.TRS(p, q, Vector3.one);
            grp[i] = (byte)(r.Next(Designs.Length) * Shapes + (i < N - OnGround ? r.Next(Shapes) : r.Next(DrapeFrom)));
            alive[i] = true;
            i++;
        }
        remaining = N;
        for (int i = 0; i < N; i++) Stamp(i, 1);
        for (int i = 0; i < N; i++) hidden[i] = Hidden(i);
    }

    // ---- GPU buffer 繪製 ----
    void SetupGpu()
    {
        staticGB = new GraphicsBuffer(GraphicsBuffer.Target.Structured, N, 64);
        dynGB = new GraphicsBuffer(GraphicsBuffer.Target.Structured, DynCap, 64);
        deadBits = new uint[(N + 31) / 32]; deadGB = new GraphicsBuffer(GraphicsBuffer.Target.Structured, deadBits.Length, 4);
        staticCpu = new Matrix4x4[N]; dynCpu = new Matrix4x4[DynCap];
        gOff = new int[G]; gCnt = new int[G]; dOff = new int[G]; dCnt = new int[G];
        sRp = new RenderParams[G * 3]; dRp = new RenderParams[G]; shRp = new RenderParams[G]; sMpb = new MaterialPropertyBlock[G * 3]; dMpb = new MaterialPropertyBlock[G];
        shMpb = new MaterialPropertyBlock[G]; lodCnt = new int[G * 3];
        var bounds = new Bounds(Vector3.zero, Vector3.one * 60);
        for (int g = 0; g < G; g++)
        {
            var mat = Resources.Load<Material>("Mats/rib_" + Designs[g / Shapes]);
            for (int l = 0; l < 3; l++)
            {
                sMpb[g * 3 + l] = new MaterialPropertyBlock(); sMpb[g * 3 + l].SetBuffer("_Instances", staticGB); sMpb[g * 3 + l].SetBuffer("_Dead", deadGB); sMpb[g * 3 + l].SetFloat("_UseDead", 1);
                sRp[g * 3 + l] = new RenderParams(mat) { worldBounds = bounds, shadowCastingMode = ShadowCastingMode.Off, receiveShadows = true, matProps = sMpb[g * 3 + l] };
            }
            shMpb[g] = new MaterialPropertyBlock(); shMpb[g].SetBuffer("_Instances", staticGB); shMpb[g].SetBuffer("_Dead", deadGB); shMpb[g].SetFloat("_UseDead", 1);
            dMpb[g] = new MaterialPropertyBlock(); dMpb[g].SetBuffer("_Instances", dynGB); dMpb[g].SetBuffer("_Dead", deadGB); dMpb[g].SetFloat("_UseDead", 0);
            shRp[g] = new RenderParams(mat) { worldBounds = bounds, shadowCastingMode = ShadowCastingMode.ShadowsOnly, matProps = shMpb[g] };
            dRp[g] = new RenderParams(mat) { worldBounds = bounds, shadowCastingMode = ShadowCastingMode.On, receiveShadows = true, matProps = dMpb[g] };
        }
    }

    // 大 buffer 整個重排：看得到、沒在掉的飄帶依形狀分組，組內由近到遠（近的先畫，後面被擋住的 GPU 不用算光照），上傳一次
    const int Buckets = 32;
    int[] bucketCnt, bucketCur; byte[] bucketOf; Vector3 rebuiltAt;
    readonly System.Diagnostics.Stopwatch rebuildSw = new(); int rebuilds; float settleMs, drawMs; bool drawRebuilt;
    readonly System.Diagnostics.Stopwatch pRay = new(), pLoop = new(), pRe = new(); int nearN; // 自我檢查量卡頓用
    void RebuildStatic()
    {
        rebuildSw.Start(); rebuilds++;
        bucketCnt ??= new int[G * Buckets]; bucketCur = new int[G * Buckets]; bucketOf ??= new byte[N];
        System.Array.Clear(bucketCnt, 0, bucketCnt.Length);
        rebuiltAt = player;
        for (int i = 0; i < N; i++)
        {
            if (!alive[i] || isFalling[i] || hidden[i]) continue;
            var m = mtx[i];
            float dx = m.m03 - player.x, dz = m.m23 - player.z;
            int b = Mathf.Min(Buckets - 1, (int)(Mathf.Sqrt(dx * dx + dz * dz) * 2)); // 每 0.5m 一層
            bucketOf[i] = (byte)b;
            bucketCnt[grp[i] * Buckets + b]++;
        }
        int o = 0;
        for (int g = 0; g < G; g++)
        {
            gOff[g] = o;
            for (int b = 0; b < Buckets; b++)
            {
                if (b == LodNearB) lodCnt[g * 3] = o - gOff[g];
                if (b == LodMidB) lodCnt[g * 3 + 1] = o - gOff[g] - lodCnt[g * 3];
                bucketCur[g * Buckets + b] = o; o += bucketCnt[g * Buckets + b];
            }
            gCnt[g] = o - gOff[g];
            lodCnt[g * 3 + 2] = gCnt[g] - lodCnt[g * 3] - lodCnt[g * 3 + 1];
            if (noLod) { lodCnt[g * 3] = gCnt[g]; lodCnt[g * 3 + 1] = lodCnt[g * 3 + 2] = 0; }
        }
        for (int i = 0; i < N; i++)
        {
            inExtra[i] = false;
            if (!alive[i] || isFalling[i] || hidden[i]) { slotOf[i] = -1; continue; }
            int s = bucketCur[grp[i] * Buckets + bucketOf[i]]++;
            staticCpu[s] = mtx[i]; slotOf[i] = s;
        }
        staticGB.SetData(staticCpu, 0, 0, o);
        System.Array.Clear(deadBits, 0, deadBits.Length); deadCount = 0; deadDirty = true;
        extra.Clear(); rebuildNow = false; nextRebuild = Time.time + 1f;
        rebuildSw.Stop();
    }

    void TakeOut(int i) { int s = slotOf[i]; if (s >= 0) { deadBits[s >> 5] |= 1u << (s & 31); deadCount++; deadDirty = true; slotOf[i] = -1; } } // 大 buffer 那格標成已移除
    void ShowLater(int i) { if (slotOf[i] < 0 && !inExtra[i] && alive[i] && !isFalling[i]) { inExtra[i] = true; extra.Add(i); } } // 先每幀畫，之後併回大 buffer

    void DrawRibbons()
    {
        bool moved2m = (player - rebuiltAt).sqrMagnitude > 4 && Time.time >= nextRebuild; // 走遠了，重排一次遠近順序
        if (rebuildNow || deadCount > 20000 || (extra.Count > 0 && Time.time >= nextRebuild) || moved2m) RebuildStatic();
        if (deadDirty) { deadGB.SetData(deadBits); deadDirty = false; }
        for (int g = 0; g < G; g++)
            if (gCnt[g] > 0)
            {
                // 同一組裡已經由近到遠排好：前段用細的網格，後段越遠越粗
                for (int l = 0, b = gOff[g]; l < 3; b += lodCnt[g * 3 + l], l++)
                    if (lodCnt[g * 3 + l] > 0)
                    {
                        sMpb[g * 3 + l].SetFloat("_Base", b);
                        Graphics.RenderMeshPrimitives(sRp[g * 3 + l], lodMeshes[l][g % Shapes], 0, lodCnt[g * 3 + l]);
                    }
                shMpb[g].SetFloat("_Base", gOff[g]);
                Graphics.RenderMeshPrimitives(shRp[g], shadowMeshes[g % Shapes], 0, gCnt[g]);
            }

        // 小堆：正在掉、剛落地／剛露出來（還沒併回大 buffer）、被吸走的
        System.Array.Clear(dCnt, 0, G);
        foreach (int i in falling) dCnt[grp[i]]++;
        foreach (int i in extra) if (inExtra[i] && alive[i] && !isFalling[i]) dCnt[grp[i]]++;
        foreach (var f in flies) dCnt[f.g]++;
        int total = 0;
        for (int g = 0; g < G; g++) { dOff[g] = total; total += dCnt[g]; }
        if (total > DynCap) { rebuildNow = true; return; } // 太多了，下一幀直接重排大 buffer
        var cur = (int[])dOff.Clone();
        foreach (int i in falling) dynCpu[cur[grp[i]]++] = mtx[i];
        foreach (int i in extra) if (inExtra[i] && alive[i] && !isFalling[i]) dynCpu[cur[grp[i]]++] = mtx[i];
        var nozzle = NozzleWorld;
        foreach (var f in flies) dynCpu[cur[f.g]++] = Matrix4x4.TRS(f.p, f.q, Vector3.one * (f.burst ? 0.22f : Mathf.Clamp((nozzle - f.p).magnitude / 1.5f, 0.05f, 1))); // 彩帶是小紙片
        if (total == 0) return;
        dynGB.SetData(dynCpu, 0, 0, total);
        for (int g = 0; g < G; g++)
            if (dCnt[g] > 0) { dMpb[g].SetFloat("_Base", dOff[g]); Graphics.RenderMeshPrimitives(dRp[g], meshes[g % Shapes], 0, dCnt[g]); }
    }

    // ---- 體素格 ----
    static int VoxIndex(Vector3 p)
    {
        int x = Mathf.FloorToInt((p.x - GridLo.x) / Vox), y = Mathf.FloorToInt((p.y - GridLo.y) / Vox), z = Mathf.FloorToInt((p.z - GridLo.z) / Vox);
        if (x < 0 || y < 0 || z < 0 || x >= GX || y >= GY || z >= GZ) return -1;
        return (z * GY + y) * GX + x;
    }

    void Stamp(int i, int delta)
    {
        for (int s = 0; s < Samples; s++) { int v = VoxIndex(Vector3.Lerp(segA[i], segB[i], s / (Samples - 1f))); if (v >= 0) vox[v] += (short)delta; }
    }

    bool Deep(Vector3 p)
    {
        foreach (var o in Around) { int v = VoxIndex(p + o); if (v < 0 || vox[v] < HideThr) return false; }
        return true;
    }
    bool Hidden(int i) => Deep(segA[i]) && Deep((segA[i] + segB[i]) * 0.5f) && Deep(segB[i]);

    void Recheck(int i) { hidden[i] = Hidden(i); if (!hidden[i]) ShowLater(i); } // 旁邊被挖開了，看得到就要畫

    // 中間底下有東西撐，或兩端都有東西撐，才算穩；只掛一端的會掉下來
    bool Supported(int i) => Rests(i, 0.5f) || (Rests(i, 0) && Rests(i, 1));

    bool Rests(int i, float t)
    {
        var below = Vector3.Lerp(segA[i], segB[i], t) + Vector3.down * 0.1f;
        if (below.y <= 0 || (below - babyPos).sqrMagnitude < BabyR * BabyR) return true;
        int v = VoxIndex(below);
        if (v < 0 || vox[v] < SupportMin) return false;
        if (vox[v] - Samples >= SupportMin) return true; // 就算全是自己的也夠，不用數
        int own = 0;
        for (int s = 0; s < Samples; s++) if (VoxIndex(Vector3.Lerp(segA[i], segB[i], s / (Samples - 1f))) == v) own++;
        return vox[v] - own >= SupportMin;
    }

    // ponytail: 只把整條平移 + 慢慢轉平，落地換成垂掛的形狀；不做真的布料模擬
    void Settle(float dt)
    {
        if (watch.Count == 0) return;
        for (int k = 0, cnt = Mathf.Min(ChecksPerFrame, watch.Count); k < cnt; k++) // 輪流檢查，一幀不超過 ChecksPerFrame 條
        {
            int i = watch[watchCursor++ % watch.Count];
            if (alive[i] && !isFalling[i] && !Supported(i)) { isFalling[i] = true; fallV[i] = 0; falling.Add(i); fell++; TakeOut(i); }
        }
        for (int n = falling.Count - 1; n >= 0; n--)
        {
            int i = falling[n];
            if (!alive[i]) { isFalling[i] = false; falling.RemoveAt(n); continue; }
            fallV[i] = Mathf.Max(fallV[i] - 9.8f * dt, -2.5f);          // 紙飄帶空氣阻力大，掉得慢
            Stamp(i, -1);
            var c = (segA[i] + segB[i]) * 0.5f;
            c += new Vector3(Mathf.Sin(Time.time * 4 + i) * 0.25f * dt, Mathf.Max(fallV[i] * dt, -0.09f), Mathf.Cos(Time.time * 3 + i) * 0.25f * dt); // 飄著往下
            var fwd = rot[i] * Vector3.forward; fwd.y = 0;
            if (fwd.sqrMagnitude < 1e-4f) fwd = Vector3.right;
            var flat = Quaternion.LookRotation(fwd.normalized, (rot[i] * Vector3.up).y >= 0 ? Vector3.up : Vector3.down);
            rot[i] = Quaternion.RotateTowards(rot[i], flat, 160 * dt);   // 邊掉邊躺平
            var dir = rot[i] * Vector3.forward * HalfLen;
            float low = Mathf.Min(c.y - dir.y, c.y + dir.y);
            bool ground = low < 0.01f;
            if (ground) c.y += 0.01f - low;
            segA[i] = c - dir; segB[i] = c + dir;
            mtx[i] = Matrix4x4.TRS(c, rot[i], Vector3.one);
            Stamp(i, 1);
            if (ground || Supported(i))
            {
                isFalling[i] = false; falling.RemoveAt(n); hidden[i] = false; GridPut(i);
                grp[i] = (byte)(grp[i] / Shapes * Shapes + DrapeFrom + Random.Range(0, Shapes - DrapeFrom)); // 落地：軟軟地垂掛
                ShowLater(i);
            }
        }
        if (falling.Count > 0) watchUntil = Time.time + 0.5f;
        else if (Time.time > watchUntil + watch.Count / (float)ChecksPerFrame / 60f)
        {
            foreach (int i in watch) { watched[i] = false; if (alive[i]) Recheck(i); } // 掉完了，附近被露出來的要開始畫
            watch.Clear(); watchCursor = 0;
        }
    }

    // ---- 玩家碰撞：體素格裡取樣點夠多的格子當成實心 ----
    bool SolidAt(Vector3 p) { int v = VoxIndex(p); return v >= 0 && vox[v] >= Thr; }

    bool Blocked(Vector3 feet, float from, float to)
    {
        for (float y = from; y <= to + 1e-4f; y += Vox)
            foreach (var o in Ring) if (SolidAt(feet + new Vector3(o.x * PR, y, o.y * PR))) return true;
        return false;
    }

    // 腳下（往上 StepH 以內）最高的實心面；沒有就是地面 0
    float SupportTop(Vector3 f)
    {
        float best = 0;
        int jHi = Mathf.Min(GY - 1, Mathf.FloorToInt((f.y + StepH) / Vox)), jLo = Mathf.Max(0, Mathf.FloorToInt((f.y - 0.02f) / Vox));
        foreach (var o in Ring)
        {
            int ix = Mathf.FloorToInt((f.x + o.x * PR - GridLo.x) / Vox), iz = Mathf.FloorToInt((f.z + o.y * PR - GridLo.z) / Vox);
            if (ix < 0 || iz < 0 || ix >= GX || iz >= GZ) continue;
            for (int j = jHi; j >= jLo; j--)
                if (vox[(iz * GY + j) * GX + ix] >= Thr) { best = Mathf.Max(best, (j + 1) * Vox); break; }
        }
        return best;
    }

    void MovePlayer(float dt)
    {
        if (noclip) return;
        float speed = Input.GetKey(KeyCode.LeftShift) ? 4 : 2;
        var keys = new Vector3(Input.GetAxisRaw("Horizontal"), 0, Input.GetAxisRaw("Vertical")) + new Vector3(botMove.x, 0, botMove.y);
        var wish = Quaternion.Euler(0, yaw, 0) * keys.normalized * speed * dt;
        bool wasGrounded = grounded; float y0 = player.y;
        if (!Blocked(player + new Vector3(wish.x, 0, 0), StepH, bodyH)) player.x += wish.x; // 分軸走，貼著牆可以滑
        if (!Blocked(player + new Vector3(0, 0, wish.z), StepH, bodyH)) player.z += wish.z;
        player.x = Mathf.Clamp(player.x, -19, 19); player.z = Mathf.Clamp(player.z, -19, 19);

        bool wantCrouch = Input.GetKey(KeyCode.C) || Input.GetKey(KeyCode.LeftControl);
        if (wantCrouch) bodyH = CrouchH;
        else if (bodyH < StandH && !Blocked(player, CrouchH, StandH)) bodyH = StandH; // 頭上有東西就繼續蹲

        if (grounded && Input.GetKeyDown(KeyCode.Space)) vy = 5f;
        vy = Mathf.Max(vy - 20 * dt, -12);
        player.y += vy * dt;
        if (vy > 0 && Blocked(player, bodyH, bodyH)) vy = 0; // 撞頭
        grounded = false;
        if (vy <= 0)
        {
            float top = SupportTop(player);
            if (player.y <= top + 1e-3f) { player.y = top; vy = 0; grounded = true; }
            else if (wasGrounded)
            {
                // 往下走一小階就貼著地面下去，不要每階都小跳一下
                float below = SupportTop(player - Vector3.up * StepH);
                if (below >= player.y - StepH - 0.02f) { player.y = below; vy = 0; grounded = true; }
            }
        }
        // 走路時的高低差先吸收在鏡頭位移裡，再慢慢回到 0：身體照格子走，鏡頭是平滑的
        if (wasGrounded && grounded) stepOffset = Mathf.Clamp(stepOffset + y0 - player.y, -0.4f, 0.4f);
    }

    // 點到線段距離
    static float SegDist(Vector3 p, Vector3 a, Vector3 b)
    {
        var ab = b - a;
        float s = Mathf.Clamp01(Vector3.Dot(p - a, ab) / ab.sqrMagnitude);
        return Vector3.Distance(p, a + s * ab);
    }

    // 射線打到的第一條飄帶：回傳距離 t 和是哪一條（沒打到 t = +inf）
    // ponytail: 三十萬條暴力掃一遍約 2-3 ms；要更快再用體素格做 DDA
    // 中點落在哪一格（0.5m）。飄帶落地時再放進新格子；舊格子裡的舊紀錄靠 cellOf 判斷略過
    const float GCell = 0.5f; const int GCX = 38, GCY = 12, GCZ = 38;
    static readonly Vector3 GLo = new(-9.5f, 0, -9.5f);
    List<int>[] cells; int[] cellOf, cellSeen; int queryId;
    readonly List<int> cand = new();
    int CellIdx(Vector3 p)
    {
        int x = Mathf.Clamp(Mathf.FloorToInt((p.x - GLo.x) / GCell), 0, GCX - 1), y = Mathf.Clamp(Mathf.FloorToInt((p.y - GLo.y) / GCell), 0, GCY - 1), z = Mathf.Clamp(Mathf.FloorToInt((p.z - GLo.z) / GCell), 0, GCZ - 1);
        return (z * GCY + y) * GCX + x;
    }
    void GridPut(int i) { int c = CellIdx((segA[i] + segB[i]) * 0.5f); if (cellOf[i] == c) return; cellOf[i] = c; cells[c].Add(i); }
    void InitGrid()
    {
        cells = new List<int>[GCX * GCY * GCZ]; for (int c = 0; c < cells.Length; c++) cells[c] = new List<int>();
        cellOf = new int[N]; cellSeen = new int[cells.Length];
        for (int i = 0; i < N; i++) { cellOf[i] = -1; GridPut(i); }
    }
    // 把 [lo, hi] 盒子裡、這次查詢還沒看過的格子中的活飄帶加進 list（同一個 queryId 內不重複）
    void Gather(Vector3 lo, Vector3 hi, List<int> list)
    {
        int x0 = Mathf.Max(0, Mathf.FloorToInt((lo.x - GLo.x) / GCell)), x1 = Mathf.Min(GCX - 1, Mathf.FloorToInt((hi.x - GLo.x) / GCell));
        int y0 = Mathf.Max(0, Mathf.FloorToInt((lo.y - GLo.y) / GCell)), y1 = Mathf.Min(GCY - 1, Mathf.FloorToInt((hi.y - GLo.y) / GCell));
        int z0 = Mathf.Max(0, Mathf.FloorToInt((lo.z - GLo.z) / GCell)), z1 = Mathf.Min(GCZ - 1, Mathf.FloorToInt((hi.z - GLo.z) / GCell));
        for (int z = z0; z <= z1; z++)
            for (int y = y0; y <= y1; y++)
                for (int x = x0; x <= x1; x++)
                {
                    int c = (z * GCY + y) * GCX + x;
                    if (cellSeen[c] == queryId) continue;
                    cellSeen[c] = queryId;
                    foreach (int i in cells[c]) if (alive[i] && cellOf[i] == c) list.Add(i);
                }
    }

    // 準心打到的第一條：沿著射線每 0.5m 收附近格子裡的飄帶來算，打到之後再往前多看一點就停
    float RayHit(Ray ray, out int hit)
    {
        float best = float.PositiveInfinity; hit = -1;
        Vector3 o = ray.origin, d = ray.direction;
        var pad = Vector3.one * (HalfLen + HitRad + 0.26f);
        queryId++;
        for (float ts = 0; ts <= Reach + 1f && ts <= best + 1.2f; ts += GCell)
        {
            var q = o + d * ts; cand.Clear(); Gather(q - pad, q + pad, cand);
            foreach (int i in cand)
            {
                Vector3 a = segA[i], u = segB[i] - a, w = o - a;
                float bu = Vector3.Dot(d, u), cu = Vector3.Dot(u, u), dw = Vector3.Dot(d, w), ew = Vector3.Dot(u, w);
                float den = cu - bu * bu;
                float s = den > 1e-6f ? Mathf.Clamp01((ew - dw * bu) / den) : 0;
                float t = s * bu - dw;
                if (t < 0 || t >= best) continue;
                if ((w + t * d - s * u).sqrMagnitude < HitRad * HitRad) { best = t; hit = i; }
            }
        }
        return best;
    }

    // 舊的暴力版，只給自我檢查對答案
    float RayHitBrute(Ray ray, out int hit)
    {
        float best = float.PositiveInfinity; hit = -1;
        Vector3 o = ray.origin, d = ray.direction;
        for (int i = 0; i < N; i++)
        {
            if (!alive[i]) continue;
            Vector3 a = segA[i], u = segB[i] - a, w = o - a;
            float bu = Vector3.Dot(d, u), cu = Vector3.Dot(u, u), dw = Vector3.Dot(d, w), ew = Vector3.Dot(u, w);
            float den = cu - bu * bu;
            float s = den > 1e-6f ? Mathf.Clamp01((ew - dw * bu) / den) : 0;
            float t = s * bu - dw;
            if (t < 0 || t >= best) continue;
            if ((w + t * d - s * u).sqrMagnitude < HitRad * HitRad) { best = t; hit = i; }
        }
        return best;
    }

    void Click(Ray ray)
    {
        if (wonTime >= 0) return;
        pRay.Start(); float t = RayHit(ray, out int hit); pRay.Stop();
        var toBaby = babyPos - ray.origin;
        float tb = Vector3.Dot(toBaby, ray.direction);
        if (tb > 0 && tb - BabyR < Reach && (toBaby - tb * ray.direction).magnitude < BabyR && tb - BabyR < t) { Found(); return; }
        if (t > Reach) return;
        kick = 1;
        float rad = SuckR[suckLv];
        var c = rad <= 0 ? ray.GetPoint(t) : ray.GetPoint(t + rad * 0.6f);
        if (rad > 0 && (c - babyPos).sqrMagnitude < (rad + BabyR) * (rad + BabyR)) { Found(); return; } // 吸的範圍碰到奶龍也算
        if (rad <= 0) Grab(c, 0, hit);       // Lv1：只吸準心那一條
        else Grab(c, rad);                   // 往裡面挖一團
    }

    // 找到了：奶龍被吸出洞、飛到玩家面前落地，噴一圈彩帶；原本的洞讓旁邊的飄帶照重力塌下來
    float foundAt; Vector3 babyFrom, babyTo, babyMid;
    void Found()
    {
        var sw = System.Diagnostics.Stopwatch.StartNew();
        wonTime = Time.time - startTime; foundAt = Time.time; kick = 1;
        var fwd = Quaternion.Euler(0, yaw, 0) * Vector3.forward;
        babyFrom = babyPos;
        var land = player + fwd * 0.9f;
        babyTo = new Vector3(land.x, TopAt(land.x, land.z, player.y + 0.4f) + BabyR, land.z);
        babyMid = Vector3.Lerp(babyFrom, NozzleWorld, 0.8f) + Vector3.up * 0.4f; // 先往吸嘴衝，再彈到面前
        babyPos = new Vector3(0, -10, 0); // 原位置不再撐著飄帶
        queryId++; cand.Clear();
        Gather(babyFrom - Vector3.one * 1.3f, babyFrom + new Vector3(1.3f, 99, 1.3f), cand);
        foreach (int i in cand) { if (!watched[i]) { watched[i] = true; watch.Add(i); } Recheck(i); }
        watchUntil = Time.time + 0.5f;
        winMs = sw.ElapsedMilliseconds;
    }

    // (x, z) 這一柱從 fromY 往下第一個實心格的頂面；沒有就是地面
    float TopAt(float x, float z, float fromY)
    {
        int ix = Mathf.FloorToInt((x - GridLo.x) / Vox), iz = Mathf.FloorToInt((z - GridLo.z) / Vox);
        if (ix < 0 || iz < 0 || ix >= GX || iz >= GZ) return 0;
        for (int j = Mathf.Min(GY - 1, Mathf.FloorToInt(fromY / Vox)); j >= 0; j--)
            if (vox[(iz * GY + j) * GX + ix] >= Thr) return (j + 1) * Vox;
        return 0;
    }

    Vector3 Eye => player + Vector3.up * (eye + stepOffset);
    Ray Aim => new(Eye, Quaternion.Euler(pitch, yaw, 0) * Vector3.forward);

    void LookAt(Vector3 p)
    {
        var d = p - Eye;
        yaw = Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg;
        pitch = -Mathf.Atan2(d.y, new Vector2(d.x, d.z).magnitude) * Mathf.Rad2Deg;
    }

    Vector3 NozzleWorld => vac.TransformPoint(Vacuum.Nozzle);

    // 吸走 c 半徑 rad 內的飄帶（only >= 0 時只吸那一條）；洞附近的列入重力觀察、重新判斷看不看得到
    void Grab(Vector3 c, float rad, int only = -1)
    {
        int n = 0;
        var nozzle = NozzleWorld;
        float watchR = rad + HalfLen + 0.4f;
        var near = new List<int>();
        pLoop.Start();
        queryId++; cand.Clear();
        Gather(new Vector3(c.x - watchR, Mathf.Min(c.y - watchR, c.y - rad - 0.2f), c.z - watchR), new Vector3(c.x + watchR, 99, c.z + watchR), cand);
        foreach (int i in cand)
        {
            if (!alive[i]) continue;
            Vector3 p = (segA[i] + segB[i]) * 0.5f;
            bool take = only >= 0 ? i == only : SegDist(c, segA[i], segB[i]) <= rad;
            if (!take)
            {
                if ((p - c).sqrMagnitude < watchR * watchR) near.Add(i);
                if (!watched[i] && p.y > c.y - rad - 0.2f && new Vector2(p.x - c.x, p.z - c.z).sqrMagnitude < watchR * watchR)
                { watched[i] = true; watch.Add(i); }
                continue;
            }
            alive[i] = false; n++;
            Stamp(i, -1); TakeOut(i);
            if (flies.Count < MaxFly)
                flies.Add(new Fly
                {
                    g = grp[i], p = p, q = rot[i],
                    v = (nozzle - p).normalized * Random.Range(1f, 3f) + Random.insideUnitSphere * 1.5f,
                    axis = Random.onUnitSphere, spin = Random.Range(100f, 400f), life = 2.5f,
                });
        }
        pLoop.Stop();
        watchUntil = Time.time + 0.5f;
        pRe.Start(); foreach (int i in near) Recheck(i); pRe.Stop(); nearN += near.Count; // 洞旁邊的露出來了
        remaining -= n; moved += n; coins += n;
    }

    void Update()
    {
        // 第一人稱：滑鼠看、WASD 走（Shift 跑）、空白鍵跳、C / Ctrl 蹲。飄帶山可以爬上去站，要進去得自己吸出洞
        float dt = Time.deltaTime;
        bool locked = Cursor.lockState == CursorLockMode.Locked;
        if (locked) { yaw += Input.GetAxis("Mouse X") * 2; pitch = Mathf.Clamp(pitch - Input.GetAxis("Mouse Y") * 2, -85, 85); }
        MovePlayer(dt);
        eye = Mathf.Lerp(eye, bodyH < StandH ? CrouchEye : standEye, dt * 12);
        stepOffset *= Mathf.Exp(-dt * 9); // 約 0.25 秒跟上
        cam.transform.SetPositionAndRotation(Eye, Quaternion.Euler(pitch, yaw, 0));
        kick = Mathf.MoveTowards(kick, 0, dt * 5);
        vac.localPosition = VacPos + new Vector3(Random.Range(-1f, 1f), Random.Range(-1f, 1f), -4) * 0.006f * kick; // 吸的時候抖一下

        var prof = System.Diagnostics.Stopwatch.StartNew();
        Settle(dt);
        settleMs = (float)prof.Elapsed.TotalMilliseconds;

        if (Input.GetKeyDown(KeyCode.Escape)) Cursor.lockState = CursorLockMode.None; // 放開滑鼠去點升級
        if (Input.GetKeyDown(KeyCode.R)) UnityEngine.SceneManagement.SceneManager.LoadScene(0);
        if (Input.GetKeyDown(KeyCode.E)) Buy();

        // 按住左鍵一直吸；滑鼠沒鎖時點畫面（不在升級面板上）先鎖回來
        var mp = Input.mousePosition;
        bool overUI = panel.Contains(new Vector2(mp.x, Screen.height - mp.y));
        if (shotPrefix == null && !locked && !overUI && Input.GetMouseButtonDown(0)) Cursor.lockState = CursorLockMode.Locked;
        // 每點一下都馬上吸（狂點可以比間隔快）；按住不放就每隔一個間隔自動再吸
        else if (shotPrefix == null && locked && (Input.GetMouseButtonDown(0) || (Input.GetMouseButton(0) && Time.time >= nextSuck))) { Click(Aim); nextSuck = Time.time + SuckEvery[suckLv]; }

        // 被吸進吸嘴的飄帶：往吸嘴加速，碰到吸嘴就消失
        var nozzle = NozzleWorld;
        for (int i = flies.Count - 1; i >= 0; i--)
        {
            var f = flies[i];
            var to = nozzle - f.p; float dist = to.magnitude;
            f.life -= dt;
            if (f.burst) { f.v.y -= 5 * dt; f.v *= 1 - 1.5f * dt; dist = 1; } // 紙片：往上噴、慢慢飄下來
            else { f.v += to / Mathf.Max(dist, 0.01f) * 50 * dt; f.v *= 1 - 2.5f * dt; }
            f.p += f.v * dt; f.q = Quaternion.AngleAxis(f.spin * dt, f.axis) * f.q;
            if (f.life <= 0 || dist < 0.1f || f.p.y < 0) { flies.RemoveAt(i); continue; }
            flies[i] = f;
        }

        prof.Restart(); int rb0 = rebuilds;
        DrawRibbons();
        drawMs = (float)prof.Elapsed.TotalMilliseconds; drawRebuilt = rebuilds != rb0;

        if (wonTime >= 0) AnimateFound(dt);
    }

    const float FlyDur = 1.1f;
    bool burstDone;
    void AnimateFound(float dt)
    {
        float t = Time.time - foundAt, u = Mathf.Clamp01(t / FlyDur);
        var face = cam.transform.position - baby.position; face.y = 0;
        if (face.sqrMagnitude < 1e-4f) face = Vector3.back;
        if (u < 1)
        {
            // 二次貝茲：洞裡 → 吸嘴前 → 面前地上；邊飛邊轉、往前拉長
            float e = 1 - (1 - u) * (1 - u);
            var pos = Vector3.Lerp(Vector3.Lerp(babyFrom, babyMid, e), Vector3.Lerp(babyMid, babyTo, e), e);
            float stretch = Mathf.Sin(u * Mathf.PI) * 0.25f;
            baby.SetPositionAndRotation(pos, Quaternion.LookRotation(face) * Quaternion.Euler(0, (1 - e) * 720, 0));
            baby.localScale = new Vector3(1 - stretch * 0.5f, 1 + stretch, 1 - stretch * 0.5f);
        }
        else
        {
            if (!burstDone)
            {
                burstDone = true;
                var away = baby.position - cam.transform.position; away.y = 0; away.Normalize();
                for (int k = 0; k < 140; k++)
                {
                    // 往上、往奶龍後面噴，不要糊在鏡頭前
                    var dir = (Vector3.up * Random.Range(1.2f, 2f) + away * Random.Range(0.2f, 1f) + Random.insideUnitSphere * 0.7f).normalized;
                    flies.Add(new Fly { g = Random.Range(0, G), p = babyTo + Vector3.up * 0.2f, q = Random.rotation, v = dir * Random.Range(2f, 3.5f), axis = Random.onUnitSphere, spin = Random.Range(200f, 600f), life = 4f, burst = true });
                }
            }
            // 落地後開心地蹦：每次著地壓扁一下
            float h = t - FlyDur, ph = Mathf.Repeat(h * 1.6f, 1f);
            float hop = 4 * ph * (1 - ph) * 0.12f, squash = Mathf.Exp(-ph * 12) * 0.18f;
            baby.SetPositionAndRotation(babyTo + Vector3.up * hop, Quaternion.LookRotation(face) * Quaternion.Euler(0, Mathf.Sin(h * 5) * 15, 0));
            baby.localScale = new Vector3(1 + squash * 0.6f, 1 - squash, 1 + squash * 0.6f);
        }
        if (t < 1.6f) // 鏡頭慢慢轉過去看奶龍，不硬切
        {
            var d = baby.position - Eye;
            float ty = Mathf.Atan2(d.x, d.z) * Mathf.Rad2Deg, tp = -Mathf.Atan2(d.y, new Vector2(d.x, d.z).magnitude) * Mathf.Rad2Deg;
            float k = 1 - Mathf.Exp(-dt * 6);
            yaw = Mathf.LerpAngle(yaw, ty, k); pitch = Mathf.Lerp(pitch, tp, k);
        }
    }

    void OnGUI()
    {
        GUI.skin.font = hudFont ??= Resources.Load<Font>("Fonts/hud"); // 網頁版沒有系統中文字型，自帶一份只含用到字的 Noto Sans TC
        GUI.skin.label.fontSize = GUI.skin.button.fontSize = GUI.skin.box.fontSize = 20;
        float elapsed = wonTime >= 0 ? wonTime : Time.time - startTime;
        GUI.Label(new Rect(16, 10, 1000, 30), $"用吸塵器找出埋在 30 萬條洋流飄帶裡的奶龍　剩 {remaining:N0} 條　{(int)elapsed / 60}:{(int)elapsed % 60:00}");
        GUI.Label(new Rect(16, 38, 1200, 30), "WASD 走（Shift 跑）　空白鍵跳　滑鼠看　點或按住左鍵吸　C 蹲　E 升級　Esc 放開滑鼠　R 重來");
        var cross = new GUIStyle(GUI.skin.label) { fontSize = 28, alignment = TextAnchor.MiddleCenter };
        GUI.Label(new Rect(Screen.width / 2 - 20, Screen.height / 2 - 20, 40, 40), "+", cross);

        panel = new Rect(Screen.width - 370, Screen.width < 1500 ? 72 : 10, 360, 120); // 視窗窄（網頁嵌入）時放到兩行說明下面，免得疊字
        GUI.Box(panel, "");
        GUI.Label(new Rect(panel.x + 14, panel.y + 10, 340, 30), $"金幣：{coins:N0}（吸一條 +1）");
        bool max = suckLv + 1 >= SuckCost.Length;
        string now = SuckR[suckLv] <= 0 ? $"一次一條・每 {SuckEvery[suckLv]}s" : $"{SuckR[suckLv] * 100:0}cm・每 {SuckEvery[suckLv]}s";
        string label = max ? $"[E] 吸力 Lv{suckLv + 1}（{now}）已滿" : $"[E] 吸力 Lv{suckLv + 1}（{now}）\n升級：{SuckCost[suckLv + 1]:N0} 金幣";
        GUI.enabled = !max && coins >= SuckCost[suckLv + 1];
        if (GUI.Button(new Rect(panel.x + 10, panel.y + 50, 340, 60), label)) Buy();
        GUI.enabled = true;

        if (wonTime >= 0 && Time.time - foundAt > FlyDur) // 奶龍落地後才跳結算
        {
            var big = new GUIStyle(GUI.skin.box) { fontSize = 34, alignment = TextAnchor.MiddleCenter };
            GUI.Box(new Rect(Screen.width / 2 - 450, 90, 900, 130),
                $"找到奶龍了！\n{(int)wonTime / 60}:{(int)wonTime % 60:00}・吸了 {moved:N0} 條・吸力 Lv{suckLv + 1}　（R 再玩一次）", big);
        }
    }

    void Buy()
    {
        if (suckLv + 1 >= SuckCost.Length || coins < SuckCost[suckLv + 1]) return;
        coins -= SuckCost[suckLv + 1]; suckLv++;
    }

    // -preview 模式：在山外面從正面、斜前、側面、背面拍奶龍
    System.Collections.IEnumerator Preview()
    {
        standEye = eye = 0.3f;
        foreach (float ang in new[] { 0f, 35f, 90f, 160f })
        {
            player = babyPos + Quaternion.Euler(0, ang, 0) * new Vector3(0, 0, -0.75f); player.y = 0;
            LookAt(babyPos + Vector3.up * 0.02f);
            yield return new WaitForSeconds(0.6f);
            ScreenCapture.CaptureScreenshot($"{shotPrefix}-{ang}.png");
            yield return null;
        }
        yield return new WaitForSeconds(0.3f);
        Application.Quit(0);
    }

    void LogTiming(string tag, int f0, float t0)
    {
        FrameTimingManager.CaptureFrameTimings(); var ft = new FrameTiming[1];
        string timing = FrameTimingManager.GetLatestTimings(1, ft) > 0 ? $" cpuMain={ft[0].cpuMainThreadFrameTime:0.0}ms cpuRender={ft[0].cpuRenderThreadFrameTime:0.0}ms gpu={ft[0].gpuFrameTime:0.0}ms" : "";
        Debug.Log($"SELFCHECK {tag} fps={(Time.frameCount - f0) / (Time.realtimeSinceStartup - t0):0}{timing}");
    }

    // -shot 模式：量效能（不鎖幀）→ 從天上掉到山頂 → 山腰吸大洞看飄帶掉 → 對著奶龍一路吸 → 過關 → 近拍
    System.Collections.IEnumerator SelfCheck()
    {
        QualitySettings.vSyncCount = 0; Application.targetFrameRate = 500; // 量真正的上限
        if (boots >= 2)
        {
            // 重玩後的第二輪：飄帶山要正常出現；順便同一個畫面 LOD 開 / 關輪流量，排除機器忙不忙的影響
            yield return new WaitForSeconds(1f);
            int shownR = 0; for (int i = 0; i < N; i++) if (slotOf[i] >= 0) shownR++;
            Debug.Log($"SELFCHECK restart ok drawn={shownR} remaining={remaining} won={wonTime >= 0}");
            for (int k = 0; k < 4; k++)
            {
                noLod = k % 2 == 1; rebuildNow = true;
                yield return new WaitForSeconds(0.5f);
                int fa = Time.frameCount; float ta = Time.realtimeSinceStartup;
                yield return new WaitForSeconds(2f);
                LogTiming(noLod ? "far-noLod" : "far-lod", fa, ta);
            }
            Application.Quit(0);
            yield break;
        }
        yield return new WaitForSeconds(1f);
        int f0 = Time.frameCount; float t0 = Time.realtimeSinceStartup;
        yield return new WaitForSeconds(2f);
        int shown = 0; for (int i = 0; i < N; i++) if (slotOf[i] >= 0) shown++;
        LogTiming($"far drawn={shown}/{N}", f0, t0);
        ScreenCapture.CaptureScreenshot(shotPrefix + "-pile.png");
        yield return null;

        // 山腳，看散在地上的飄帶和山的大小
        player = new Vector3(0, 0, -PileR - 1.2f); LookAt(new Vector3(0.5f, 0.6f, 0));
        yield return new WaitForSeconds(0.6f);
        ScreenCapture.CaptureScreenshot(shotPrefix + "-foot.png");
        yield return null;

        // 物理：從山頂上方掉下來，要站在飄帶山上而不是穿過去
        player = new Vector3(0.3f, 6f, 0.3f);
        yield return new WaitForSeconds(1.5f);
        Debug.Log($"SELFCHECK landOnPile y={player.y:0.00} grounded={grounded}");

        // 走路平順：從山頂往山腳走 3 秒，比較身體和鏡頭每幀最大的高度變化
        yaw = 180; botMove = Vector2.up;
        float camPrev = Eye.y, bodyPrev = player.y, camJump = 0, bodyJump = 0, walkStart = player.z;
        for (float t = 0; t < 3; t += Time.deltaTime)
        {
            yield return null;
            camJump = Mathf.Max(camJump, Mathf.Abs(Eye.y - camPrev)); bodyJump = Mathf.Max(bodyJump, Mathf.Abs(player.y - bodyPrev));
            camPrev = Eye.y; bodyPrev = player.y;
        }
        botMove = Vector2.zero;
        Debug.Log($"SELFCHECK walk dist={Mathf.Abs(player.z - walkStart):0.0} bodyMaxStep={bodyJump:0.000} camMaxStep={camJump:0.000} endY={player.y:0.00}");

        // 重力：在山腰（奶龍的另一邊）吸一個 0.9m 的大洞，上面懸空的飄帶要飄下來
        var outDir = new Vector3(babyPos.x, 0, babyPos.z).normalized; if (outDir == Vector3.zero) outDir = Vector3.back;
        var hole = -outDir * 3.4f + Vector3.up * 1.0f;
        noclip = true; player = hole - outDir * 3.5f; player.y = 0.3f; LookAt(hole);
        yield return new WaitForSeconds(0.5f);
        f0 = Time.frameCount; t0 = Time.realtimeSinceStartup;
        yield return new WaitForSeconds(1.0f);
        LogTiming("close", f0, t0);
        Grab(hole, 0.9f);
        yield return new WaitForSeconds(0.2f);
        int fell0 = fell;
        f0 = Time.frameCount; t0 = Time.realtimeSinceStartup;
        yield return new WaitForSeconds(1.0f);
        ScreenCapture.CaptureScreenshot(shotPrefix + "-falling.png");
        LogTiming("whileFalling", f0, t0);
        yield return new WaitForSeconds(2.0f);
        Debug.Log($"SELFCHECK bigHole fellStart={fell0} fellTotal={fell} stillFalling={falling.Count}");
        ScreenCapture.CaptureScreenshot(shotPrefix + "-hole.png");
        yield return null;
        noclip = false;

        // Lv1 只吸一條
        int before = moved; player = new Vector3(0, 0, -PileR - 0.3f); LookAt(new Vector3(0, 0.3f, -PileR + 0.8f));
        yield return new WaitForSeconds(0.3f);
        Click(Aim);
        Debug.Log($"SELFCHECK lv1 sucked={moved - before}");

        // 格子版準心判定跟暴力版對答案
        {
            int bad = 0, hits = 0;
            for (int k = 0; k < 300; k++)
            {
                float ang = k * 0.7f; var from = new Vector3(Mathf.Cos(ang), 0, Mathf.Sin(ang)) * (PileR + 0.5f + (k % 5) * 0.4f) + Vector3.up * (0.3f + (k % 7) * 0.4f);
                var ray = new Ray(from, (new Vector3(Mathf.Sin(k), 1 + Mathf.Cos(k * 1.3f), Mathf.Cos(k)) - from).normalized);
                float tg = RayHit(ray, out int hg), tb = RayHitBrute(ray, out int hb);
                if (tb <= Reach) { hits++; if (hg != hb) bad++; }
                else if (tg <= Reach) bad++;
            }
            Debug.Log($"SELFCHECK rayGrid hits={hits} mismatches={bad}");
        }

        // 各等級在山腳表面吸一下平均拿走幾條（估一局多久用）
        for (int lv = 0; lv < SuckR.Length; lv++)
        {
            suckLv = lv; int got = 0;
            for (int k = 0; k < 8; k++)
            {
                float ang = (lv * 8 + k) * 0.29f + 2.0f;
                var dirOut = new Vector3(Mathf.Cos(ang), 0, Mathf.Sin(ang));
                player = dirOut * (PileR + 0.4f); LookAt(dirOut * (PileR - 1.2f) + Vector3.up * 0.5f);
                int m0 = moved; Click(Aim); got += moved - m0;
            }
            Debug.Log($"SELFCHECK perSuck lv={lv + 1} r={SuckR[lv]} every={SuckEvery[lv]} avg={got / 8f:0.0}");
            yield return null;
        }

        // 最高等級在山上連吸 8 秒：最卡的一幀、每次吸花多久、重排大 buffer 花多久
        suckLv = SuckR.Length - 1;
        player = new Vector3(-outDir.x, 0, -outDir.z) * (PileR + 0.5f);
        yield return new WaitForSeconds(0.5f);
        for (int pass = 0; pass < 2; pass++)
        { 
            float worst = 0, sumDt = 0; int frames = 0; string worstWhy = ""; int gc0 = System.GC.CollectionCount(0);
            var spikes = new List<string>(); int spikeN = 0; bool prevClicked = false, prevRebuilt = false; float prevSettle = 0, prevDraw = 0; long clickTicks = 0, clickMax = 0; int clicks = 0;
            rebuildSw.Reset(); rebuilds = 0; float next = 0; pRay.Reset(); pLoop.Reset(); pRe.Reset(); nearN = 0;
            for (float t = 0; t < 8; t += Time.unscaledDeltaTime)
            {
                bool clicked = pass == 1 && t >= next; // 第一輪不吸，當對照組
                if (clicked)
                {
                    next += SuckEvery[suckLv];
                    LookAt(new Vector3(0, 1.0f + Mathf.Sin(t) * 0.6f, 0) + Quaternion.Euler(0, t * 9, 0) * Vector3.right * 0.8f);
                    var cs = System.Diagnostics.Stopwatch.StartNew(); Click(Aim); cs.Stop();
                    clickTicks += cs.ElapsedTicks; clickMax = System.Math.Max(clickMax, cs.ElapsedTicks); clicks++;
                }
                yield return null;
                if (Time.unscaledDeltaTime > 0.05f) spikeN++;
                if (Time.unscaledDeltaTime > 0.05f && spikes.Count < 12 && pass == 1)
                {
                    FrameTimingManager.CaptureFrameTimings(); var ft = new FrameTiming[1]; FrameTimingManager.GetLatestTimings(1, ft);
                    spikes.Add($"{Time.unscaledDeltaTime * 1000:0}ms prevClick={prevClicked} prevSettle={prevSettle:0.0} prevDraw={prevDraw:0.0} prevRebuilt={prevRebuilt} gpu={ft[0].gpuFrameTime:0} cpu={ft[0].cpuFrameTime:0}");
                }
                prevClicked = clicked; prevSettle = settleMs; prevDraw = drawMs; prevRebuilt = drawRebuilt;
                if (Time.unscaledDeltaTime > worst) { worst = Time.unscaledDeltaTime; worstWhy = $"settle={settleMs:0.0} draw={drawMs:0.0} rebuilt={drawRebuilt} gc={System.GC.CollectionCount(0) - gc0} watch={watch.Count} falling={falling.Count} extra={extra.Count}"; }
                gc0 = System.GC.CollectionCount(0);
                sumDt += Time.unscaledDeltaTime; frames++;
            }
            double tick = 1000.0 / System.Diagnostics.Stopwatch.Frequency;
            Debug.Log($"SELFCHECK {(pass == 0 ? "idleSameSpot" : "suckMax")} spikes50={spikeN} fps={frames / sumDt:0} worstFrameMs={worst * 1000:0} clickAvgMs={clickTicks * tick / Mathf.Max(1, clicks):0.0} clickMaxMs={clickMax * tick:0.0} rebuilds={rebuilds} rebuildAvgMs={rebuildSw.Elapsed.TotalMilliseconds / Mathf.Max(1, rebuilds):0.0} watch={watch.Count} falling={falling.Count}");
            Debug.Log($"SELFCHECK worstFrame {worstWhy}");
            if (clicks > 0) Debug.Log($"SELFCHECK clickParts ray={pRay.Elapsed.TotalMilliseconds / clicks:0.0} loop={pLoop.Elapsed.TotalMilliseconds / clicks:0.0} recheck={pRe.Elapsed.TotalMilliseconds / clicks:0.0} near={nearN / clicks}");
            foreach (var sp in spikes) Debug.Log("SELFCHECK spike " + sp);
        }

        // 走到奶龍那一側的山坡上，對著奶龍一路往下吸（最高等級）
        player = new Vector3(babyPos.x, 0, babyPos.z) + outDir * 3.2f;
        yield return new WaitForSeconds(0.5f);
        f0 = Time.frameCount; t0 = Time.realtimeSinceStartup;
        int digClicks = 0; float digStart = Time.time;
        for (int i = 0; i < 600 && wonTime < 0; i++, digClicks++)
        {
            LookAt(babyPos);
            Click(Aim);
            yield return new WaitForSeconds(0.05f);
            if (i == 30) LogTiming("whileSucking", f0, t0);
        }
        Debug.Log($"SELFCHECK dig clicks={digClicks} gameSeconds={digClicks * SuckEvery[suckLv]:0}");
        Debug.Log($"SELFCHECK won={wonTime >= 0} winClickMs={winMs} moved={moved} remaining={remaining} fell={fell} playerY={player.y:0.00}");
        yield return new WaitForSeconds(0.55f);
        ScreenCapture.CaptureScreenshot(shotPrefix + "-flying.png");
        yield return new WaitForSeconds(1.3f);
        ScreenCapture.CaptureScreenshot(shotPrefix + "-won.png");
        var toB = baby.position - player; toB.y = 0;
        Debug.Log($"SELFCHECK landed dist={toB.magnitude:0.00} babyY={baby.position.y:0.00} landY={babyTo.y:0.00} confetti={flies.Count}");
        yield return new WaitForSeconds(1.5f);
        Debug.Log($"SELFCHECK afterWin fell={fell} stillFalling={falling.Count}");
        yield return new WaitForSeconds(0.5f);
        if (wonTime < 0) Application.Quit(1);
        UnityEngine.SceneManagement.SceneManager.LoadScene(0); // 跟按 R 一樣
    }
}
