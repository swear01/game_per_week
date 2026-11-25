// 洋流飄帶專用：矩陣放在 GPU buffer（_Instances[_Base + instanceID]），CPU 不用每幀上傳；
// 光照跟 URP Lit 一樣（PBR + 主光陰影 + 環境光）。
Shader "OceanBaby/RibbonInstanced"
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _BaseColor ("Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        StructuredBuffer<float4x4> _Instances;
        StructuredBuffer<uint> _Dead;     // 每個格子一個 bit：被吸走的就縮成一點，不畫
        float _Base, _UseDead;
        TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
        CBUFFER_END

        struct Attributes { float3 pos : POSITION; float3 normal : NORMAL; float2 uv : TEXCOORD0; uint id : SV_InstanceID; };

        void ToWorld(Attributes a, out float3 ws, out float3 n)
        {
            uint slot = (uint)_Base + a.id;
            float4x4 m = _Instances[slot];
            if (_UseDead > 0.5 && ((_Dead[slot >> 5] >> (slot & 31)) & 1)) { ws = 0; n = float3(0, 1, 0); return; }
            ws = mul(m, float4(a.pos, 1)).xyz;
            n = normalize(mul((float3x3)m, a.normal));
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            Cull Back
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Varyings { float4 cs : SV_POSITION; float3 ws : TEXCOORD0; float3 n : TEXCOORD1; float2 uv : TEXCOORD2; };

            Varyings vert(Attributes a)
            {
                Varyings o;
                ToWorld(a, o.ws, o.n);
                o.cs = TransformWorldToHClip(o.ws);
                o.uv = TRANSFORM_TEX(a.uv, _BaseMap);
                return o;
            }

            // 跟 URP Lit 同一套 PBR 光照（smoothness 0.3），畫面不打折；省的是 CPU 上傳和看不到的飄帶
            half4 frag(Varyings i) : SV_Target
            {
                float3 n = normalize(i.n);
                InputData d = (InputData)0;
                d.positionWS = i.ws;
                d.positionCS = i.cs;
                d.normalWS = n;
                d.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.ws);
                d.shadowCoord = TransformWorldToShadowCoord(i.ws);
                d.bakedGI = SampleSH(n);
                d.shadowMask = half4(1, 1, 1, 1);
                d.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.cs);

                SurfaceData s = (SurfaceData)0;
                s.albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).rgb * _BaseColor.rgb;
                s.smoothness = 0.3;
                s.occlusion = 1;
                s.alpha = 1;
                return UniversalFragmentPBR(d, s);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On ColorMask 0 Cull Back
            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            float3 _LightDirection;

            float4 vert(Attributes a) : SV_POSITION
            {
                float3 ws, n;
                ToWorld(a, ws, n);
                float4 cs = TransformWorldToHClip(ApplyShadowBias(ws, n, _LightDirection));
                #if UNITY_REVERSED_Z
                    cs.z = min(cs.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    cs.z = max(cs.z, UNITY_NEAR_CLIP_VALUE);
                #endif
                return cs;
            }
            half4 frag() : SV_Target { return 0; }
            ENDHLSL
        }
    }
}
