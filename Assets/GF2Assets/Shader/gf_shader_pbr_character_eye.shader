/*
===============================================================
Shader Variants:
    - "_CHARACTER_EFFECT"
    - "_GF_CHAR_LOD1"
    - "_GF_CHAR_LOD2"
    - "_MOTION_VECTOR"
    - "_EXPONENTIAL_HEIGHT_FOG"
    - "_MRT"
    - "_ADDITIONAL_LIGHT_SHADOWS"
    - "_MAIN_LIGHT_SHADOWS"
    - "_MAIN_LIGHT_SHADOWS_CASCADE"

================================================================
*/

Shader "gf_shader/pbr/character/eye" {
	Properties {
		_MainTex ("MainTex", 2D) = "white" {}
		_BaseColor ("Main Color", Color) = (1,1,1,1)
		_ShadowIntensity ("Shadow Intensity", Range(0, 1)) = 0.25
		_Specularmap ("Specular Map", 2D) = "black" {}
		_SpecularIntensity ("Specular Intensity", Range(0, 3)) = 1.5
		_CorneaParallax ("Cornea Parallax", Range(0, 0.5)) = 0.3
		_SpecularParallax ("Specular Parallax", Range(0, 1)) = 0.3
		_ShadowBiasDistance ("Shadow Bias Distance", Range(0, 1)) = 0.1
		[HideInInspector] _QueueOffset ("Queue offset", Float) = 1
		[HideInInspector] _StencilRefE ("_StencilRefE", Float) = 204
		[HideInInspector] _FinalTint ("Final Tint", Vector) = (1,1,1,1)
		[HideInInspector] _HolographicColor ("Holographic Color", Color) = (1,1,1,1)
		[HideInInspector] _HolographicIntensity ("Holographic Intensity", Range(0, 1)) = 0
		[HideInInspector] _HolographicWidth ("Holographic Width", Float) = 200
		[HideInInspector] _ConcealLerp ("Conceal Lerp", Range(0, 1)) = 0
		[HideInInspector] _CharSaturation ("Char Saturation", Range(0, 1)) = 0
	}
	SubShader {
		Tags { "QUEUE" = "Geometry+14" "RenderType" = "GfCharacter" }
		Pass {
			Name "GFCharForward"
			Tags { "LIGHTMODE" = /*"GFCharForward"*/"UniversalForward" "QUEUE" = "Geometry+14" "RenderType" = "GfCharacter" }
			ColorMask RGB
			//ColorMask 0
			Stencil {
				Comp Always
				Pass Replace
				Fail Keep
				ZFail Keep
			}
			GpuProgramID 64450
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			struct v2f
			{
				float4 position : SV_POSITION0;
				float4 texcoord : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				float4 texcoord3 : TEXCOORD3;
				float4 texcoord4 : TEXCOORD4;
				float4 texcoord5 : TEXCOORD5;
				float4 texcoord6 : TEXCOORD6;
			};
			struct fout
			{
				float4 sv_target : SV_TARGET0;
			};
			// $Globals ConstantBuffers for Vertex Shader
			// $Globals ConstantBuffers for Fragment Shader
			float4 _MainLightPosition;
			float4 _MainLightColor;
			float4 _AdditionalLightsCount;
			float4 _AdditionalLightsPosition[256];
			float4 _AdditionalLightsColor[256];
			float4 _AdditionalLightsAttenuation[256];
			float4 _AdditionalLightsSpotDir[256];
			// Custom ConstantBuffers for Vertex Shader
			CBUFFER_START(UnityPerDraw)
				float4 unity_LightData;
				float4 unity_LightIndices[2];
			CBUFFER_END
			CBUFFER_START(UnityPerMaterial)
				float4 _MainTex_ST;
			CBUFFER_END
			// Custom ConstantBuffers for Fragment Shader
			CBUFFER_START(UnityPerMaterial)
				float4 _FinalTint;
				float _SpecularIntensity;
				float _CorneaParallax;
				float _SpecularParallax;
				float _ShadowIntensity;
			CBUFFER_END
			// Texture params for Vertex Shader
			// Texture params for Fragment Shader
			sampler2D _MainTex;
			sampler2D _Specularmap;
			
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
                o.position = tmp1 + unity_MatrixVP._m03_m13_m23_m33;
                o.texcoord.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.texcoord.zw = float2(0.0, 0.0);
                tmp1.x = dot(v.normal.xyz, unity_WorldToObject._m00_m10_m20);
                tmp1.y = dot(v.normal.xyz, unity_WorldToObject._m01_m11_m21);
                tmp1.z = dot(v.normal.xyz, unity_WorldToObject._m02_m12_m22);
                tmp0.w = dot(tmp1.xyz, tmp1.xyz);
                tmp0.w = max(tmp0.w, 0.0);
                tmp0.w = rsqrt(tmp0.w);
                o.texcoord1.xyz = tmp0.www * tmp1.xyz;
                o.texcoord1.w = 0.0;
                o.texcoord2 = v.color;
                o.texcoord3.w = 0.0;
                tmp1.xyz = _WorldSpaceCameraPos - tmp0.xyz;
                o.texcoord6.xyz = tmp0.xyz;
                o.texcoord3.xyz = tmp1.xyz;
                o.texcoord4 = float4(0.0, 0.0, 0.0, 0.0);
                tmp0.xyz = tmp1.yyy * unity_WorldToObject._m01_m11_m21;
                tmp0.xyz = unity_WorldToObject._m00_m10_m20 * tmp1.xxx + tmp0.xyz;
                tmp0.xyz = unity_WorldToObject._m02_m12_m22 * tmp1.zzz + tmp0.xyz;
                tmp0.w = dot(tmp0.xyz, tmp0.xyz);
                tmp0.w = rsqrt(tmp0.w);
                tmp0.xyz = tmp0.www * tmp0.xyz;
                tmp0.x = dot(tmp0.xyz, tmp0.xyz);
                tmp0.x = rsqrt(tmp0.x);
                tmp0.x = tmp0.x * tmp0.z;
                tmp0.x = tmp0.x * v.color.y;
                tmp0.x = tmp0.x * v.tangent.w;
                o.texcoord5.x = tmp0.x * unity_WorldTransformParams.w;
                o.texcoord5.yzw = float3(0.0, 0.0, 0.0);
                o.texcoord6.w = 0.0;
                return o;
			}
			// Keywords: 
			fout frag(v2f o, float facing: VFACE)
			{
                fout output;
                const float4 icb[4] = {
                    float4(1.0, 0.0, 0.0, 0.0),
                    float4(0.0, 1.0, 0.0, 0.0),
                    float4(0.0, 0.0, 1.0, 0.0),
                    float4(0.0, 0.0, 0.0, 1.0)
                };
					float4 u_xlat0;
					float4 u_xlat1;
					float4 u_xlat2;
					float3 u_xlat3;
					float3 u_xlat4;
					float4 u_xlat5;
					float3 u_xlat6;
					float u_xlat7;
					float3 u_xlat11;
					float u_xlat21;
					uint u_xlatu21;
					float u_xlat22;
					uint u_xlatu22;
					float u_xlat23;
					int u_xlati23;
					bool u_xlatb23;
					float u_xlat24;
					uint u_xlatu24;
					float u_xlat25;
					    u_xlat0.x = dot(o.texcoord1.xyz, o.texcoord1.xyz);
					    u_xlat0.x = rsqrt(u_xlat0.x);
					    u_xlat0.xyz = u_xlat0.xxx * o.texcoord1.xyz;
					    u_xlat1 = o.texcoord5.xyxy * float4(_CorneaParallax, _CorneaParallax, _SpecularParallax, _SpecularParallax) + o.texcoord.xyxy;
					    u_xlat2 = tex2D(_MainTex, u_xlat1.xy);
					    u_xlat1 = tex2D(_Specularmap, u_xlat1.zw);
					    u_xlat3.xyz = u_xlat1.xyz * _SpecularIntensity;
					    u_xlat22 = dot(u_xlat0.xyz, _MainLightPosition.xyz);
					    u_xlat22 = clamp(u_xlat22, 0.0, 1.0);
					    u_xlat3.xyz = u_xlat22 * u_xlat3.xyz;
					    u_xlat4.xyz = u_xlat2.xyz * _MainLightColor.xyz;
					    u_xlat23 = (-_ShadowIntensity) + 1.0;
					    u_xlat22 = u_xlat22 * u_xlat23 + _ShadowIntensity;
					    u_xlat4.xyz = u_xlat22 * u_xlat4.xyz;
					    u_xlat3.xyz = u_xlat3.xyz * _MainLightColor.xyz + u_xlat4.xyz;
					    u_xlat0.w = 1.0;
					    u_xlat4.x = dot(unity_SHAr, u_xlat0);
					    u_xlat4.y = dot(unity_SHAg, u_xlat0);
					    u_xlat4.z = dot(unity_SHAb, u_xlat0);
					    u_xlat5 = u_xlat0.yzzx * u_xlat0.xyzz;
					    u_xlat6.x = dot(unity_SHBr, u_xlat5);
					    u_xlat6.y = dot(unity_SHBg, u_xlat5);
					    u_xlat6.z = dot(unity_SHBb, u_xlat5);
					    u_xlat7 = u_xlat0.y * u_xlat0.y;
					    u_xlat0.x = u_xlat0.x * u_xlat0.x + (-u_xlat7);
					    u_xlat0.xyz = unity_SHC.xyz * u_xlat0.xxx + u_xlat6.xyz;
					    u_xlat0.xyz = u_xlat0.xyz + u_xlat4.xyz;
					    u_xlat0.xyz = max(u_xlat0.xyz, float3(0.00100000005, 0.00100000005, 0.00100000005));
					    u_xlat21 = dot(u_xlat0.xyz, float3(0.212672904, 0.715152204, 0.0721750036));
					    u_xlat4.x = unity_SHBr.z;
					    u_xlat4.y = unity_SHBg.z;
					    u_xlat4.z = unity_SHBb.z;
					    u_xlat5.x = unity_SHAr.w;
					    u_xlat5.y = unity_SHAg.w;
					    u_xlat5.z = unity_SHAb.w;
					    u_xlat4.xyz = u_xlat4.xyz * float3(0.333299994, 0.333299994, 0.333299994) + u_xlat5.xyz;
					    u_xlat22 = dot(u_xlat4.xyz, float3(0.212672904, 0.715152204, 0.0721750036));
					    u_xlat0.xyz = u_xlat0.xyz / u_xlat21;
					    u_xlat0.xyz = u_xlat22 * u_xlat0.xyz;
					    u_xlat0.xyz = u_xlat0.xyz * u_xlat2.xyz + u_xlat3.xyz;
					    u_xlat21 = min(_AdditionalLightsCount.x, unity_LightData.y);
					    u_xlatu21 =  uint(int(u_xlat21));
					    u_xlat3.xyz = o.texcoord1.xyz * float3(0.0199999996, 0.0199999996, 0.0199999996) + o.texcoord6.xyz;
					    u_xlat1.xyz = u_xlat1.xyz * _SpecularIntensity + u_xlat2.xyz;
					    u_xlat2.xyz = u_xlat0.xyz;
					    for(uint u_xlatu_loop_1 = 0u ; u_xlatu_loop_1<u_xlatu21 ; u_xlatu_loop_1++)
					    {
					        //AND
					        u_xlati23 = int(u_xlatu_loop_1 & 3u);
					        //USHR
					        u_xlatu24 = u_xlatu_loop_1 >> 2u;
					        //DP4
					        u_xlat23 = dot(unity_LightIndices[int(u_xlatu24)], icb[u_xlati23]);
					        //FTOI
					        u_xlati23 = int(u_xlat23);
					        //MAD
					        u_xlat4.xyz = (-u_xlat3.xyz) * _AdditionalLightsPosition[u_xlati23].www + _AdditionalLightsPosition[u_xlati23].xyz;
					        //DP3
					        u_xlat24 = dot(u_xlat4.xyz, u_xlat4.xyz);
					        //MAX
					        u_xlat24 = max(u_xlat24, 1.17549435e-38);
					        //RSQ
					        u_xlat25 = rsqrt(u_xlat24);
					        //MUL
					        u_xlat4.xyz = u_xlat25 * u_xlat4.xyz;
					        //DIV
					        u_xlat25 = float(1.0) / u_xlat24;
					        //MUL
					        u_xlat24 = u_xlat24 * _AdditionalLightsAttenuation[u_xlati23].x;
					        //MAD
					        u_xlat24 = (-u_xlat24) * u_xlat24 + 1.0;
					        //MAX
					        u_xlat24 = max(u_xlat24, 0.0);
					        //MUL
					        u_xlat24 = u_xlat24 * u_xlat24;
					        //MUL
					        u_xlat24 = u_xlat24 * u_xlat25;
					        //DP3
					        u_xlat25 = dot(_AdditionalLightsSpotDir[u_xlati23].xyz, u_xlat4.xyz);
					        //MAD
					        u_xlat25 = u_xlat25 * _AdditionalLightsAttenuation[u_xlati23].z + _AdditionalLightsAttenuation[u_xlati23].w;
					        u_xlat25 = clamp(u_xlat25, 0.0, 1.0);
					        //MUL
					        u_xlat25 = u_xlat25 * u_xlat25;
					        //MUL
					        u_xlat24 = u_xlat24 * u_xlat25;
					        //DP3
					        u_xlat4.x = dot(o.texcoord1.xyz, u_xlat4.xyz);
					        //MAX
					        u_xlat4.x = max(u_xlat4.x, 0.0);
					        //MUL
					        u_xlat11.xyz = u_xlat1.xyz * _AdditionalLightsColor[u_xlati23].xyz;
					        //MUL
					        u_xlat11.xyz = u_xlat24 * u_xlat11.xyz;
					        //MAD
					        u_xlat2.xyz = u_xlat11.xyz * u_xlat4.xxx + u_xlat2.xyz;
					    }
					    output.sv_target.xyz = u_xlat2.xyz * _FinalTint.xyz;
					    output.sv_target.w = 0.0;
                return output;
			}
			ENDCG
		}
	}
	Fallback "Hidden/Universal Render Pipeline/FallbackError"
}