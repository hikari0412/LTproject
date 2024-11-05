Shader "gf_shader/pbr/character/eyeblend_multiply" {
	Properties {
		_MainColor ("Main Color", Color) = (1,1,1,0.85)
		_MainTex ("Mask", 2D) = "white" {}
		_SpecularIntensity ("Multiply Intensity", Range(0, 1)) = 1
		[Header(Character Effect)] [HideInInspector] _HolographicColor ("Holographic Color", Color) = (1,1,1,1)
		[HideInInspector] _HolographicIntensity ("Holographic Intensity", Range(0, 1)) = 0
		[HideInInspector] _HolographicWidth ("Holographic Width", Float) = 200
		[HideInInspector] _ConcealLerp ("Conceal Lerp", Range(0, 1)) = 0
		[HideInInspector] _CharSaturation ("Char Saturation", Range(0, 1)) = 0
	}
	SubShader {
		Tags { "QUEUE" = "Transparent+9" "RenderType" = "GfCharacter" }
		Pass {
			Name "GFCharForward"
			Tags { "LIGHTMODE" = /*"UniversalForward"*/"UniversalForward" "QUEUE" = "Transparent+9" "RenderType" = "GfCharacter" }
			Blend 0 DstColor Zero, DstColor Zero
			ColorMask RGB 0
			Blend 1 Zero One, Zero One
			ColorMask RGA 1
			ZWrite Off
			GpuProgramID 29178
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
                tmp0 = tex2D(_MainTex, o.texcoord.xy);
                tmp0.xyz = tmp0.xyz * _MainColor.xyz + float3(-1.0, -1.0, -1.0);
                output.sv_target.xyz = _SpecularIntensity.xxx * tmp0.xyz + float3(1.0, 1.0, 1.0);
                output.sv_target.w = 1.0;
                return output;
			}
			ENDCG
		}
	}
	Fallback "Hidden/Universal Render Pipeline/FallbackError"
}