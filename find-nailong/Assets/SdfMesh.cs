using System.Collections.Generic;
using UnityEngine;

// SDF 小工具：基本形、平滑相融，和把 SDF 轉成平滑網格的 surface nets。奶龍和吸塵器都用這個做曲面。
public static class SdfMesh
{
    // ---- SDF 基本形 ----
    public static float Ell(Vector3 p, Vector3 c, Vector3 r)
    {
        var q = p - c;
        float k0 = new Vector3(q.x / r.x, q.y / r.y, q.z / r.z).magnitude;
        float k1 = new Vector3(q.x / (r.x * r.x), q.y / (r.y * r.y), q.z / (r.z * r.z)).magnitude;
        return k1 < 1e-6f ? -Mathf.Min(r.x, Mathf.Min(r.y, r.z)) : k0 * (k0 - 1) / k1;
    }
    public static float Cap(Vector3 p, Vector3 a, Vector3 b, float ra, float rb)
    {
        Vector3 pa = p - a, ba = b - a;
        float h = Mathf.Clamp01(Vector3.Dot(pa, ba) / ba.sqrMagnitude);
        return (pa - ba * h).magnitude - Mathf.Lerp(ra, rb, h);
    }
    public static float SMin(float a, float b, float k) { float h = Mathf.Clamp01(0.5f + 0.5f * (b - a) / k); return Mathf.Lerp(b, a, h) - k * h * (1 - h); }
    public static float SMax(float a, float b, float k) => -SMin(-a, -b, k);

    public static float Box(Vector3 p, Vector3 c, Vector3 half, float round)
    {
        var q = p - c; q = new Vector3(Mathf.Abs(q.x), Mathf.Abs(q.y), Mathf.Abs(q.z)) - half + Vector3.one * round;
        return Vector3.Max(q, Vector3.zero).magnitude + Mathf.Min(Mathf.Max(q.x, Mathf.Max(q.y, q.z)), 0) - round;
    }

    public static Vector3 Grad(System.Func<Vector3, float> sdf, Vector3 p, float e = 0.002f) => new Vector3(
        sdf(p + new Vector3(e, 0, 0)) - sdf(p - new Vector3(e, 0, 0)),
        sdf(p + new Vector3(0, e, 0)) - sdf(p - new Vector3(0, e, 0)),
        sdf(p + new Vector3(0, 0, e)) - sdf(p - new Vector3(0, 0, e))).normalized;

    // 把 SDF 的零等值面轉成平滑網格（naive surface nets）。lo/hi 是取樣範圍，paint 給頂點色，toWorld 換成輸出座標
    public static Mesh SurfaceNets(System.Func<Vector3, float> Sdf, System.Func<Vector3, Color> paint, System.Func<Vector3, Vector3> toWorld, Vector3 lo, Vector3 hi, float Cell)
    {
        Vector3 o = lo, ext = hi - lo;
        int nx = Mathf.CeilToInt(ext.x / Cell) + 1, ny = Mathf.CeilToInt(ext.y / Cell) + 1, nz = Mathf.CeilToInt(ext.z / Cell) + 1;
        Vector3 P(int i, int j, int k) => o + new Vector3(i, j, k) * Cell;
        int I(int i, int j, int k) => (k * ny + j) * nx + i;

        var f = new float[nx * ny * nz];
        for (int k = 0; k < nz; k++) for (int j = 0; j < ny; j++) for (int i = 0; i < nx; i++) f[I(i, j, k)] = Sdf(P(i, j, k));

        // 每個跨過表面的格子放一個頂點（邊上交點的平均）
        int cx = nx - 1, cy = ny - 1;
        int C(int i, int j, int k) => (k * cy + j) * cx + i;
        var vid = new int[cx * cy * (nz - 1)];
        var verts = new List<Vector3>();
        var cv = new float[8];
        for (int k = 0; k < nz - 1; k++) for (int j = 0; j < cy; j++) for (int i = 0; i < cx; i++)
        {
            int neg = 0;
            for (int c = 0; c < 8; c++) { cv[c] = f[I(i + (c & 1), j + (c >> 1 & 1), k + (c >> 2 & 1))]; if (cv[c] < 0) neg++; }
            if (neg == 0 || neg == 8) { vid[C(i, j, k)] = -1; continue; }
            Vector3 sum = Vector3.zero; int cnt = 0;
            for (int a = 0; a < 8; a++) for (int bit = 1; bit < 8; bit <<= 1)
            {
                if ((a & bit) != 0) continue;
                int b = a | bit;
                if (cv[a] < 0 == cv[b] < 0) continue;
                float t = cv[a] / (cv[a] - cv[b]);
                var pa = new Vector3(a & 1, a >> 1 & 1, a >> 2 & 1); var pb = new Vector3(b & 1, b >> 1 & 1, b >> 2 & 1);
                sum += Vector3.Lerp(pa, pb, t); cnt++;
            }
            vid[C(i, j, k)] = verts.Count;
            verts.Add(P(i, j, k) + sum / cnt * Cell);
        }

        // 每條跨過表面的格線，周圍四個格子連成一個四邊形
        var tris = new List<int>();
        void Quad(int a, int b, int c, int d) { Tri(a, b, c); Tri(a, c, d); }
        void Tri(int a, int b, int c)
        {
            Vector3 A = verts[a], B = verts[b], Cc = verts[c], ctr = (A + B + Cc) / 3;
            bool flip = Vector3.Dot(Vector3.Cross(B - A, Cc - A), Grad(Sdf, ctr)) < 0;
            if (flip) tris.AddRange(new[] { a, c, b }); else tris.AddRange(new[] { a, b, c });
        }
        for (int k = 1; k < nz - 1; k++) for (int j = 1; j < ny - 1; j++) for (int i = 1; i < nx - 1; i++)
        {
            float v = f[I(i, j, k)];
            if (v < 0 != f[I(i + 1, j, k)] < 0) Quad(vid[C(i, j - 1, k - 1)], vid[C(i, j, k - 1)], vid[C(i, j, k)], vid[C(i, j - 1, k)]);
            if (v < 0 != f[I(i, j + 1, k)] < 0) Quad(vid[C(i - 1, j, k - 1)], vid[C(i, j, k - 1)], vid[C(i, j, k)], vid[C(i - 1, j, k)]);
            if (v < 0 != f[I(i, j, k + 1)] < 0) Quad(vid[C(i - 1, j - 1, k)], vid[C(i, j - 1, k)], vid[C(i, j, k)], vid[C(i - 1, j, k)]);
        }

        var normals = new Vector3[verts.Count];
        var world = new Vector3[verts.Count];
        var colors = new Color[verts.Count];
        for (int n = 0; n < verts.Count; n++) { normals[n] = Grad(Sdf, verts[n]); world[n] = toWorld(verts[n]); colors[n] = paint(verts[n]); }
        var mesh = new Mesh { indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
        mesh.SetVertices(world); mesh.SetNormals(normals); mesh.SetColors(colors);
        mesh.SetTriangles(tris, 0);
        mesh.RecalculateBounds();
        return mesh;
    }
}
