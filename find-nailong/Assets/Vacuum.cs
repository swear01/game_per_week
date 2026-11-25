using UnityEngine;
using static SdfMesh;

// 玩家手上的手持吸塵器：握把、馬達、集塵桶、長吸管、喇叭口吸嘴，整支一片曲面。
// 單位公尺，原點在握把，吸管朝 +Z。
public static class Vacuum
{
    public static readonly Vector3 Nozzle = new(0, -0.055f, 0.63f); // 吸嘴口（本地座標）

    static readonly Color Purple = new(0.45f, 0.18f, 0.62f), Bin = new(0.72f, 0.82f, 0.90f), Red = new(0.86f, 0.18f, 0.22f),
        Dark = new(0.13f, 0.13f, 0.15f), Gold = new(0.95f, 0.72f, 0.22f);

    static float Grip(Vector3 p) => Cap(p, new(0, -0.02f, -0.03f), new(0, -0.12f, 0.01f), 0.019f, 0.017f);
    static float Motor(Vector3 p) => SMin(Cap(p, new(0, 0.03f, -0.10f), new(0, 0.03f, 0.03f), 0.042f, 0.040f),
                                          Ell(p, new(0, 0.03f, -0.11f), new(0.05f, 0.05f, 0.035f)), 0.02f);
    static float DustBin(Vector3 p) => Cap(p, new(0, -0.035f, -0.01f), new(0, -0.035f, 0.14f), 0.046f, 0.046f);
    static float Wand(Vector3 p) => Cap(p, new(0, -0.035f, 0.15f), new(0, -0.05f, 0.56f), 0.017f, 0.015f);
    static float Flare(Vector3 p) => Cap(p, new(0, -0.05f, 0.54f), new(0, -0.055f, 0.63f), 0.016f, 0.036f);

    static float Sdf(Vector3 p)
    {
        float d = SMin(Grip(p), Motor(p), 0.02f);
        d = SMin(d, DustBin(p), 0.015f);
        d = SMin(d, Wand(p), 0.012f);
        d = SMin(d, Flare(p), 0.01f);
        return SMax(d, -Cap(p, new(0, -0.055f, 0.60f), new(0, -0.055f, 0.70f), 0.028f, 0.028f), 0.004f); // 吸嘴挖空
    }

    static Color Paint(Vector3 p)
    {
        Color c = Purple;
        c = Color.Lerp(c, Bin, Mathf.Clamp01((0.006f - DustBin(p)) / 0.006f) * Mathf.Clamp01(-p.y / 0.01f));
        c = Color.Lerp(c, Gold, Mathf.Clamp01(1 - Mathf.Abs(p.z - 0.035f) / 0.008f) * Mathf.Clamp01((p.y - 0.0f) / 0.01f)); // 馬達前緣金環
        c = Color.Lerp(c, Red, Mathf.Clamp01((p.z - 0.16f) / 0.01f));
        c = Color.Lerp(c, Dark, Mathf.Clamp01((p.z - 0.53f) / 0.01f));
        return c.linear; // 同 Nailong.Paint：Gamma 專案裡顏色會深一點，配色照這個調
    }

    public static GameObject Build()
    {
        var go = new GameObject("吸塵器");
        go.AddComponent<MeshFilter>().sharedMesh = SurfaceNets(Sdf, Paint, p => p, new Vector3(-0.07f, -0.15f, -0.17f), new Vector3(0.07f, 0.09f, 0.66f), 0.004f);
        var r = go.AddComponent<MeshRenderer>();
        r.sharedMaterial = Resources.Load<Material>("Mats/nailong"); // 同一個乘頂點色的材質
        r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off; r.receiveShadows = false;
        return go;
    }
}
