Shader "gf_shader/pbr/character/eyeblend_add" {
	Properties {
		_MainColor ("Main Color", Color) = (1,1,1,0.85)
		_MainTex ("Mask", 2D) = "white" {}
		_SpecularIntensity ("Specular Intensity", Range(0, 2)) = 1
		_ShadowBiasDistance ("Shadow Bias Distance", Range(0, 1)) = 0.1
		[HideInInspector] _HolographicColor ("Holographic Color", Color) = (1,1,1,1)
		[HideInInspector] _HolographicIntensity ("Holographic Intensity", Range(0, 1)) = 0
		[HideInInspector] _HolographicWidth ("Holographic Width", Float) = 200
		[HideInInspector] _ConcealLerp ("Conceal Lerp", Range(0, 1)) = 0
		[HideInInspector] _CharSaturation ("Char Saturation", Range(0, 1)) = 0
	}
	SubShader {
		Tags { "QUEUE" = "Transparent+8" "RenderType" = "GfCharacter" }
		Pass {
			Name "GFCharForward"
			Tags { "LIGHTMODE" = /*"UniversalForward"*/"UniversalForward" "QUEUE" = "Transparent+8" "RenderType" = "GfCharacter" }
			Blend 0 One One, One One
			ColorMask RGB 0
			Blend 1 Zero One, Zero One
			ColorMask RGA 1
			ZWrite Off
			GpuProgramID 44620
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			struct v2f
			{
				float4 position : SV_POSITION0;
				float4 texcoord : TEXCOORD0;
				float3 texcoord1 : TEXCOORD1;
				float3 texcoord3 : TEXCOORD3;
			};
			struct fout
			{
				float4 sv_target : SV_TARGET0;
			};
			// $Globals ConstantBuffers for Vertex Shader
			// $Globals ConstantBuffers for Fragment Shader
			float4 _MainLightPosition;
			// Custom ConstantBuffers for Vertex Shader
			CBUFFER_START(UnityPerMaterial)
				float4 _MainTex_ST;
			CBUFFER_END
			// Custom ConstantBuffers for Fragment Shader
			CBUFFER_START(UnityPerMaterial)
				float4 _MainColor;
				float _SpecularIntensity;
			CBUFFER_END
			// Texture params for Vertex Shader
			// Texture params for Fragment Shader
			sampler2D _MainTex;
			
			// Keywords: 
			v2f vert(appdata_full v)
			{
                v2f o;
                float4 tmp0;
                float4 tmp1;
                tmp0.xyz = v.vertex.yyy * unity_ObjectToWorld._m01_m11_m21;
                tmp0.xyz = unity_ObjectToWorld._m00_m10_m20 * v.vertex.xxx + tmp0.xyz;
                tmp0.xyz = unity_ObjectToWorld._m02_m12_m22 * v.vertex.zzz + tmp0.xyz;
                tmp0.xyz = tmp0.xyz + unity_ObjectToWorld._m03_m13_m23;
                tmp1 = tmp0.yyyy * unity_MatrixVP._m01_m11_m21_m31;
                tmp1 = unity_MatrixVP._m00_m10_m20_m30 * tmp0.xxxx + tmp1;
                tmp1 = unity_MatrixVP._m02_m12_m22_m32 * tmp0.zzzz + tmp1;
                o.texcoord3.xyz = tmp0.xyz;
                o.position = tmp1 + unity_MatrixVP._m03_m13_m23_m33;
                o.texcoord.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.texcoord.zw = float2(0.0, 0.0);
                tmp0.x = dot(v.normal.xyz, unity_WorldToObject._m00_m10_m20);
                tmp0.y = dot(v.normal.xyz, unity_WorldToObject._m01_m11_m21);
                tmp0.z = dot(v.normal.xyz, unity_WorldToObject._m02_m12_m22);
                tmp0.w = dot(tmp0.xyz, tmp0.xyz);
                tmp0.w = max(tmp0.w, 0.0);
                tmp0.w = rsqrt(tmp0.w);
                o.texcoord1.xyz = tmp0.www * tmp0.xyz;
                return o;
			}
			// Keywords: 
			fout frag(v2f o)
			{
                fout output;
                float4 tmp0;
                float4 tmp1;
                tmp0.x = saturate(dot(o.texcoord1.xyz, _MainLightPosition.xyz));
                tmp0.x = tmp0.x * 0.8 + 0.2;
                tmp1 = tex2D(_MainTex, o.texcoord.xy);
                tmp1 = tmp1 * _MainColor;
                tmp0.yzw = tmp1.xyz * _SpecularIntensity.xxx;
                output.sv_target.w = tmp1.w;
                output.sv_target.xyz = tmp0.xxx * tmp0.yzw;
                return output;
			}
			ENDCG
		}
	}
	Fallback "Hidden/Universal Render Pipeline/FallbackError"
}