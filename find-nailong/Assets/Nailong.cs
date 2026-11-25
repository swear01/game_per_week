using System.Collections.Generic;
using UnityEngine;
using static SdfMesh;

// 奶龍：整隻用 SDF 描（橢球、錐形膠囊平滑相融，頭身一體沒有脖子），
// 再用 surface nets 轉成一整片平滑曲面網格。以下座標用「全高 = 1」的單位，面向 +Z，腳底 y = 0。
public static class Nailong
{
    const float Size = 0.4f;    // 全高（公尺）
    const float Cell = 0.01f;   // 取樣間距（單位空間）

    static readonly Vector3 Shoulder = new(0.23f, 0.53f, 0.05f), Hand = new(0.33f, 0.41f, 0.16f);
    static readonly Vector3[] ClawPos = MakeClaws();

    static Vector3[] MakeClaws()
    {
        var l = new List<Vector3>();
        var dir = (Hand - Shoulder).normalized;
        for (int i = -1; i <= 1; i++)
        {
            l.Add(Hand + dir * 0.045f + new Vector3(0, i * 0.028f, 0.01f));   // 手指爪
            l.Add(new Vector3(0.145f + i * 0.045f, 0.03f, 0.18f));             // 腳趾爪
        }
        return l.ToArray();
    }

    // ---- 奶龍的各部位 ----
    static float Claws(Vector3 m) { float d = 1; foreach (var c in ClawPos) d = Mathf.Min(d, (m - c).magnitude - 0.017f); return d; }
    static float Mouth(Vector3 p) => Mathf.Max(Ell(p, new(0, 0.685f, 0.27f), new(0.09f, 0.05f, 0.075f)), p.y - 0.69f); // D 字形張嘴
    static float Tail(Vector3 p) => Mathf.Min(
        Cap(p, new(0.06f, 0.2f, -0.17f), new(0.22f, 0.11f, -0.32f), 0.11f, 0.07f),
        Cap(p, new(0.22f, 0.11f, -0.32f), new(0.38f, 0.06f, -0.33f), 0.07f, 0.03f));

    static float Sdf(Vector3 p)
    {
        var m = new Vector3(Mathf.Abs(p.x), p.y, p.z);                                   // 左右對稱的部位
        float d = Ell(p, new(0, 0.33f, 0), new(0.30f, 0.33f, 0.26f));                    // 梨形身體
        d = SMin(d, Ell(p, new(0, 0.73f, 0.01f), new(0.235f, 0.26f, 0.22f)), 0.14f);     // 圓頂大頭，頭身直接融在一起
        d = SMin(d, Ell(p, new(0, 0.69f, 0.11f), new(0.19f, 0.13f, 0.16f)), 0.08f);      // 往前凸的嘴鼻
        d = SMin(d, Ell(p, new(0, 0.31f, 0.11f), new(0.22f, 0.24f, 0.15f)), 0.05f);      // 大肚子
        d = SMin(d, Cap(m, Shoulder, Hand, 0.07f, 0.05f), 0.05f);                         // 短手
        d = SMin(d, Cap(m, new(0.14f, 0.18f, 0), new(0.145f, 0.05f, 0.03f), 0.10f, 0.085f), 0.05f); // 粗短腿
        d = SMin(d, Ell(m, new(0.145f, 0.04f, 0.06f), new(0.10f, 0.05f, 0.13f)), 0.04f); // 腳掌
        d = SMin(d, Tail(p), 0.06f);                                                      // 粗尾巴往後側甩
        d = SMin(d, Claws(m), 0.012f);                                                    // 咖啡色小爪
        d = SMax(d, -Mouth(p), 0.012f);                                                   // 挖出嘴巴
        return Mathf.Max(d, -p.y);                                                        // 平底站好
    }

    static readonly Color Yellow = new(1f, 0.80f, 0.33f), Belly = new(1f, 0.94f, 0.80f),
        MouthIn = new(0.38f, 0.07f, 0.08f), Tongue = new(0.90f, 0.38f, 0.38f), Claw = new(0.42f, 0.26f, 0.14f);

    // 頂點顏色：交界用 SDF 距離做平滑漸變，肚子、嘴巴邊緣才不會鋸齒
    static Color Paint(Vector3 p)
    {
        var m = new Vector3(Mathf.Abs(p.x), p.y, p.z);
        float belly = Mathf.Clamp01(0.5f - Ell(p, new(0, 0.30f, 0.2f), new(0.19f, 0.22f, 0.2f)) / 0.012f) * Mathf.Clamp01((p.z - 0.02f) / 0.04f);
        var c = Color.Lerp(Yellow, Belly, belly);
        var inside = Color.Lerp(Tongue, MouthIn, Mathf.Clamp01((p.y - 0.645f) / 0.02f));
        c = Color.Lerp(c, inside, Mathf.Clamp01((0.008f - Mouth(p)) / 0.008f));
        c = Color.Lerp(c, Claw, Mathf.Clamp01((0.010f - Claws(m)) / 0.008f));
        return c.linear; // 專案是 Gamma 色彩空間，這裡等於把顏色壓深一點；現在的配色是照這個效果調的
    }

    static Vector3 ToWorld(Vector3 u) => (u - new Vector3(0, 0.5f, 0)) * Size; // 原點在身體中心

    public static GameObject Build(Material baseMat)
    {
        Material Mat(Color c, float smooth) { var mt = new Material(baseMat) { mainTexture = null, color = c }; mt.SetFloat("_Smoothness", smooth); return mt; }

        var root = new GameObject("奶龍");
        var body = new GameObject("body");
        body.transform.SetParent(root.transform, false);
        body.AddComponent<MeshFilter>().sharedMesh = SurfaceNets(Sdf, Paint, ToWorld, new Vector3(-0.5f, -0.02f, -0.42f), new Vector3(0.5f, 1.02f, 0.42f), Cell);
        var mr = body.AddComponent<MeshRenderer>();
        mr.sharedMaterial = Resources.Load<Material>("Mats/nailong"); mr.receiveShadows = false; // Particles/Lit：會乘頂點色

        // 眼睛：分很開的小黑眼 + 反光點，貼在臉上
        var black = Mat(new Color(0.04f, 0.05f, 0.05f), 0.9f); var white = Mat(Color.white, 0.9f);
        foreach (float sx in new[] { -1f, 1f })
        {
            var s = SurfaceAlongZ(sx * 0.115f, 0.80f);
            var n = Grad(Sdf, s);
            Part(root, ToWorld(s - n * 0.012f), Quaternion.LookRotation(n), new Vector3(0.068f, 0.074f, 0.045f) * Size, black);
            Part(root, ToWorld(s + n * 0.006f + new Vector3(sx * 0.008f, 0.009f, 0)), Quaternion.identity, Vector3.one * 0.014f * Size, white);
        }
        return root;
    }

    static void Part(GameObject root, Vector3 pos, Quaternion rot, Vector3 scale, Material m)
    {
        var go = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        Object.Destroy(go.GetComponent<Collider>());
        go.transform.SetParent(root.transform, false);
        go.transform.localPosition = pos; go.transform.localRotation = rot; go.transform.localScale = scale;
        var r = go.GetComponent<Renderer>(); r.sharedMaterial = m; r.receiveShadows = false;
    }

    // 從正前方往 -z 走，找臉的表面
    static Vector3 SurfaceAlongZ(float x, float y)
    {
        var p = new Vector3(x, y, 0.6f);
        for (int i = 0; i < 64; i++) { float d = Sdf(p); if (d < 1e-4f) break; p.z -= d; }
        return p;
    }
}
