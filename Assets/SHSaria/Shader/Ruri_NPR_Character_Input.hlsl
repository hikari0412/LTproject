#ifndef RURI_NPR_CHARACTER_INPUT_INCLUDED
#define RURI_NPR_CHARACTER_INPUT_INCLUDED

#include "../Common/Ruri_Common_Input.hlsl"

// NOTE: Do not ifdef the properties here as SRP batcher can not handle different layouts.
CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    half4 _BaseColor;
    half4 _SpecColor;
    float _SpecMulti;
    float _Shininess;
    half _BumpScale;
    half _RimOffset;
    half _RimThreshold;
    half _ShadowSoft;
    half _ShadowSmooth;
    
    bool _UseCutoff;
    half _Cutoff;
    
    bool _UseFace;
    bool _UseVertexColorOutline;

    float3 _FaceShadowColor;
    float _EyeShadowIntensity;
    
    float3 _ShadowColor1;
    
    half _OutlineWidth;
    half4 _OutlineColor;
    half _OutlineScale;

    bool _UseDitherClip;
    float _DitherAlpha;
    
    // SpecialState
    float _PantiesOffset;
    
    // SpecialGBuffer
    bool _HairRenderMode;
CBUFFER_END

TEXTURE2D(_BaseMap);                    SAMPLER(sampler_BaseMap);
TEXTURE2D(_BumpMap);                    SAMPLER(sampler_BumpMap);
TEXTURE2D(_RMOSMap);                    SAMPLER(sampler_RMOSMap);
TEXTURE2D(_FaceMap);                    SAMPLER(sampler_FaceMap);

#endif // RURI_NPR_CHARACTER_INPUT_INCLUDED
