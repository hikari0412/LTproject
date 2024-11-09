Shader "Ruri/SpecialGBuffer/NPR/Character/PreWriteEyeTrans"
{
    Properties 
    {
        _FaceMap ("SDF Face Tex", 2D) = "black" {}
        _MaxEyeHairDistance("Max Eye Hair Distance", Float) = 0.2
        [HideInInspector] _ModelScale("Model Scale", Float) = 1
        
        _StencilRef("Stencil Reference Value", Int) = 32 // 0x20 对应Lit模板
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comparison Function", Int) = 8 // Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass Operation", Int) = 2 // 替换
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Geometry+5"
            "RenderType" = "Opaque"
        }
        LOD 200

        Pass
        {
            Name "PreWriteEyeTrans"
            
            ZWrite Off
            ColorMask 0

            Stencil 
            {
                Ref [_StencilRef]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "GF2CharacterUberInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            
            struct appdata
            {
                half4 positionOS : POSITION;
                half2 uv : TEXCOORD0;
            };

            struct v2f_PreWriteEyeTrans
            {
                half4 positionCS : SV_POSITION;
                half2 uv : TEXCOORD0;
            };

            v2f_PreWriteEyeTrans vert(appdata inData)
            {
                v2f_PreWriteEyeTrans output = (v2f_PreWriteEyeTrans)0;
                
                half4 positionOS = mul(unity_ObjectToWorld, inData.positionOS);
                output.positionCS = mul(unity_MatrixVP, positionOS);
                output.uv = inData.uv;
                return output;
            }

            float _MaxEyeHairDistance;

            float GetLinearEyeDepthAnyProjection(float depth)
            {
                if (IsPerspectiveProjection())
                {
                    return LinearEyeDepth(depth, _ZBufferParams);
                }

                return LinearDepthToEyeDepth(depth);
            }

            void frag(v2f_PreWriteEyeTrans input)
            {
                // （尽量）避免后一个角色的眼睛透过前一个角色的头发
                float sceneDepth = GetLinearEyeDepthAnyProjection(LoadSceneDepth(input.positionCS.xy - 0.5));
                float eyeDepth = GetLinearEyeDepthAnyProjection(input.positionCS.z);
                float depthMask = step(abs(sceneDepth - eyeDepth), _MaxEyeHairDistance);

                // 眼睛、眼眶、眉毛的遮罩（不包括高光）
                float eyeMask = SAMPLE_TEXTURE2D(_FaceMap, sampler_FaceMap, input.uv).g;
                
                clip(eyeMask * depthMask - 0.5);
            }

            ENDHLSL
        } // PreWriteEyeTrans
    }
}