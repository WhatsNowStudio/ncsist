Shader "UniStorm/Clouds/Volumetric"
{
    Properties
    {
		_uHorizonColor("_uHorizonColor", Color) = (1.0, 1.0, 1.0, 1.0)
        _uCloudsColor("_uCloudsColor", Color) = (1.0, 1.0, 1.0, 1.0)
        _uLightningColor("_uLightningColor", Color) = (1.0, 1.0, 1.0, 1.0)
        _uFogColor("_uFogColor", Color) = (1.0, 1.0, 1.0, 1.0)
        _uSunDir("_uSunDir", Vector) = (0.0, 1.0, 0.0, 0.0)
        _uSunColor("_uSunColor", Color) = (1.4, 1.26, 1.19, 0.0)

        _uLightningContrast("_uLightningContrast", Range(0.0, 3.0)) = 3.0
        _uMoonDir("_uMoonDir", Vector) = (0.0, 1.0, 0.0, 0.0)
        _uMoonColor("_uMoonColor", Color) = (1.4, 1.26, 1.19, 0.0)
        _uMoonAttenuation("_uMoonAttenuation", Float) = 1.0

        _uCloudsBottom("_uCloudsBottom", Float) = 1350.0
        _uCloudsHeight("_uCloudsHeight", Float) = 2150.0

        _uCloudsCoverage("_uCloudsCoverage", Float) = 0.52
        _uCloudsCoverageBias("_uCloudsCoverageBias", Range(-1.0, 1.0)) = 0.0

        _uAttenuation("_uAttenuation", Float) = 1.0
        _uCloudsMovementSpeed("_uCloudsMovementSpeed", Range(0.0, 150)) = 20
        _uCloudsTurbulenceSpeed("_uCloudsTurbulenceSpeed", Range(0.0, 50)) = 50.0

        _uCloudsDetailStrength("_uCloudsDetailStrength", Range(0.0, 0.4)) = 0.2
        _uCloudsBaseEdgeSoftness("_uCloudsBaseEdgeSoftness", Float) = 0.1
        _uCloudsBottomSoftness("_uCloudsBottomSoftness", Float) = 0.25
        _uCloudsDensity("_uCloudsDensity", Range(0.0, 1.0)) = 0.03
        _uCloudsForwardScatteringG("_uCloudsForwardScatteringG", Float) = 0.8
        _uCloudsBackwardScatteringG("_uCloudsBackwardScatteringG", Float) = -0.2

        _uCloudsAmbientColorTop("_uCloudsAmbientColorTop", Color) = (0.87674, 0.98235, 1.1764, 0.0)
        _uCloudsAmbientColorBottom("_uCloudsAmbientColorBottom", Color) = (0.2294, 0.3941, 0.5117, 0.0)
        
        _uCloudsBaseScale("_uCloudsBaseScale", Float) = 1.51
        _uCloudsDetailScale("_uCloudsDetailScale", Float) = 20.0
        _uCurlScale("_uCurlScale", Float) = 20.0
        _uCurlStrength("_uCurlStrength", Range(0.0, 2.5)) = 1.0

        _uHorizonDarkness("_uHorizonDarkness", Range(0.0, 2.0)) = 1.0
        _uHorizonFadeStart("_uHorizonFadeStart", Float) = -0.1
        _uHorizonFadeEnd("_uHorizonFadeEnd", Float) = 0.25
		_uHorizonColorFadeStart("_uHorizonColorFadeStart", Float) = 0
		_uHorizonColorFadeEnd("_uHorizonColorFadeEnd", Float) = 0
		_uCloudAlpha("_uCloudAlpha", Range(1, 4.55)) = 3.25

		[Toggle] _MaskMoon("Moon Masked", Float) = 0
    }

SubShader
{
    Tags{ "Queue" = "Transparent" "IgnoreProjector" = "True" }
    LOD 100
    ZWrite Off

    Pass
    {
    CGPROGRAM

    #if defined(D3D11)
    #pragma warning disable x3595 // private field assigned but not used.
    #endif

    #pragma vertex vert
    #pragma fragment frag
    #pragma multi_compile LOW MEDIUM HIGH ULTRA
    #pragma multi_compile TWOD VOLUMETRIC
    #pragma multi_compile SHADOW __
    
    uniform sampler2D _uBaseNoise;
    uniform sampler2D _uCurlNoise;
    uniform sampler3D _uDetailNoise;

    uniform float _Seed; 
    uniform float _uSize;
	uniform float _uCloudAlpha;

    uniform float3 _uWorldSpaceCameraPos;

    #include "UnityCG.cginc"
    #include "cloudsInclude.cginc"

    struct appdata
    {
        float2 uv : TEXCOORD0;
        float4 vertex : POSITION;
    };

    struct v2f
    {
        float4 vertex : SV_POSITION;
        float2 uv : TEXCOORD0;
    };

    sampler2D _MainTex;
    float4 _MainTex_ST;

    inline float4 alphaBlend(float4 dst, float4 src)
    {
        float outA = max(0.001, src.a + dst.a * (1.0 - src.a));
        return float4 (
            (src.rgb + (dst.rgb * dst.a) * (1.0 - src.a)) / outA,
            outA
            );
    }

    v2f vert(appdata v)
    {
        v2f o;

        UNITY_INITIALIZE_OUTPUT(v2f, o);

        o.uv = v.uv;
        o.vertex = UnityObjectToClipPos(v.vertex);
        return o;
    }

    uniform float _uHorizonDarkness;
	uniform float _MaskMoon;

    uniform float _uHorizonFadeEnd;
    uniform float _uHorizonFadeStart;
	uniform float _uHorizonColorFadeEnd;
	uniform float _uHorizonColorFadeStart;
	float4 _uHorizonColor;

    fixed4 frag(v2f i) : SV_Target
    {
        float2 lon = (i.uv.xy + _uJitter * (1.0 / _uSize)) - 0.5;
        float a1 = length(lon) * 3.141592;
        float sin1 = sin(a1);
        float cos1 = cos(a1);
        float cos2 = lon.x / length(lon);
        float sin2 = lon.y / length(lon);

        float3 pos = float3(sin1 * cos2, cos1, sin1 * sin2);

        float4 clouds = 0.0;

        float3 ro = float3(_uWorldSpaceCameraPos.x, 0.0, _uWorldSpaceCameraPos.z);
        float3 rd = normalize(pos);

        renderClouds(clouds, ro, rd);

        float rddotup = dot(float3(0, 1, 0), rd);
        float sstep = smoothstep(_uHorizonFadeStart, _uHorizonFadeEnd, rddotup);
		float sstep2 = smoothstep(_uHorizonColorFadeStart, _uHorizonColorFadeEnd, rddotup);
        
        #if defined(HORIZONCOLONLY)
       float4 final = float4(
                clouds.rgb * sstep, 
                (1.0 - clouds.a) * sstep
            );

        #else

		float4 final = float4(
			lerp(_uCloudsAmbientColorBottom.rgb * _uCloudAlpha * (1.0 - remap(_uCloudsCoverage + _uCloudsCoverageBias, 0.77, 0.25)),
				clouds.rgb*1.035 * sstep * sstep2,
				sstep * sstep2),
			lerp((1.0 - remap(_uCloudsCoverage + _uCloudsCoverageBias, 0.9, 0.185)),
			(1.0 - clouds.a) * sstep,
				sstep)
			);
        
		if (_MaskMoon == 1)
		{
			final = float4(final.rgb, saturate(remap(final.a, 0.0, 0.94)));
		}

        #endif

        return final;
    }
        ENDCG
}

Pass
    {
        Cull Off ZWrite Off ZTest Always
        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag

        #pragma multi_compile LOW MEDIUM HIGH ULTRA
        #pragma multi_compile TWOD VOLUMETRIC
        #pragma multi_compile __ PREWARM

        #include "UnityCG.cginc"

        uniform float       _uSize;
        uniform float2      _uJitter;
        uniform sampler2D   _uPreviousCloudTex;
        uniform sampler2D   _uLowresCloudTex;

        uniform float _uCloudsCoverageBias;
        uniform float _uLightningTimer = 0.0;

        uniform float _uConverganceRate;

        struct appdata
		{
			float4 vertex : POSITION;
			float2 uv : TEXCOORD0;
		};

		struct v2f
		{
			float4 vertex : SV_POSITION;
			float2 uv : TEXCOORD0;
		};

        v2f vert(appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.uv = v.uv;
            return o;
        }

        half4 SamplePrev(float2 uv) {
            return tex2D(_uPreviousCloudTex, uv);
        }

        half CurrentCorrect(float2 uv, float2 jitter) {
            float2 texelRelativePos = floor(fmod(uv * _uSize, 4.0)); //between (0, 4.0)

            texelRelativePos = abs(texelRelativePos - jitter);

            return saturate(texelRelativePos.x + texelRelativePos.y);
        }

        float4 SampleCurrent(float2 uv) {
            return tex2D(_uLowresCloudTex, uv);
        }

        float _uCloudsMovementSpeed;
        float remap(float v, float s, float e)
        {
            return (v - s) / (e - s);
        }

        half4 frag(v2f i) : SV_Target
        {
            float2 uvN = i.uv * 2.0 - 1.0;

            float4 currSample = SampleCurrent(i.uv);
            half4 prevSample = SamplePrev(i.uv);

            float luvN = length(uvN);

            half correct = CurrentCorrect(i.uv, _uJitter);

#if defined(PREWARM)
            return lerp(currSample, prevSample, correct); // No converging on prewarm
#endif

            float ms01 = remap(_uCloudsMovementSpeed, 0, 150);

#if defined(ULTRA) || defined (HIGH)
            float converganceSpeed = lerp(0.5, 0.95, ms01);
#else
            float converganceSpeed = lerp(lerp(0.4, 0.95, ms01), 0.85, saturate(_uLightningTimer - _Time.y) * 5.0);
#endif

            float4 final = lerp(prevSample, lerp(currSample, prevSample, correct), lerp(converganceSpeed, lerp(0.15, 0.25, ms01), luvN));

            return final;
        }

        ENDCG
    }
}
Fallback Off
}
