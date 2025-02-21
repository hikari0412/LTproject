Shader "GF2/Character/Uber/PreProjectionHairShadow"
{
    Properties 
    {
        _StencilRef("Stencil Reference Value", Int) = 33
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp("Stencil Comparison Function", Int) = 8 // Always
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPass("Stencil Pass Operation", Int) = 2 // 替换

        _FrontHairShadowOffset("FrontHairShadowOffset" , Vector ) = (-0.0045, -0.0075, 0.0, 0.0)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
        }
        LOD 200

        Pass
        {
            Name "PreProjectionHairShadow"
            
            ZWrite Off
            ColorMask 0

            Stencil {
                Ref [_StencilRef]
                Comp [_StencilComp]
                Pass [_StencilPass]
            }
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            float4 _MainLightPosition;
            float4 _FrontHairShadowOffset;

            struct appdata
            {
                half4   vertex : POSITION;
            };

            struct v2f
            {
                half4   position : SV_POSITION;
            };

            v2f vert(appdata inData)
            {
                v2f output = (v2f)0;
                
                half4 positionOS = mul(unity_ObjectToWorld, inData.vertex);
                half4 offset = half4(_MainLightPosition.x * _FrontHairShadowOffset);
                half4 positionOSOffset = positionOS + offset;
                output.position = mul(unity_MatrixVP, positionOSOffset);
                return output;
            }

            void frag(v2f inData)
            {
            }

            ENDCG
        } // PreProjectionHairShadow
    }
}