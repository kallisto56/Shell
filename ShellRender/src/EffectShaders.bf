namespace Shell.Render;

using System;

static class EffectShaders
{
	// Same vertex stage and constant buffers (b0 frame, b1 object) as Juno's default shader; user constants live in b2.
	const String cHeader = @"""
cbuffer FrameConstants : register(b0)
{
	row_major float4x4 gViewProjection;
	float gTime;
	float gDeltaTime;
	float2 gViewportSize;
};

cbuffer ObjectConstants : register(b1)
{
	row_major float4x4 gWorld;
	float4 gTint;
};

Texture2D gTexture : register(t0);
SamplerState gSampler : register(s0);

struct VSInput
{
	float3 position : POSITION;
	float2 uv       : TEXCOORD;
	float4 color    : COLOR;
};

struct PSInput
{
	float4 position : SV_POSITION;
	float2 uv       : TEXCOORD;
	float4 color    : COLOR;
};

PSInput VSMain(VSInput input)
{
	PSInput output;
	output.position = mul(mul(float4(input.position, 1.0f), gWorld), gViewProjection);
	output.uv = input.uv;
	output.color = input.color * gTint;
	return output;
}
""";

	// Separable gaussian blur over premultiplied pixels. gBlur.xy = direction in texels, gBlur.zw = texel size,
	// gRadius = blur radius in pixels (sigma = radius / 2, up to 32 taps on each side).
	const String cBlurBody = @"""
cbuffer BlurConstants : register(b2)
{
	float4 gBlur;
	float4 gRadius;
};

float4 PSMain(PSInput input) : SV_TARGET
{
	float sigma = max(gRadius.x * 0.5f, 0.001f);
	int taps = (int)min(ceil(gRadius.x * 2.0f), 32.0f);
	float4 sum = float4(0, 0, 0, 0);
	float total = 0.0f;
	[loop]
	for (int i = -32; i <= 32; i++)
	{
		if (abs(i) > taps)
			continue;
		float weight = exp(-(float)(i * i) / (2.0f * sigma * sigma));
		sum += gTexture.Sample(gSampler, input.uv + gBlur.xy * gBlur.zw * (float)i) * weight;
		total += weight;
	}
	return (sum / total) * input.color;
}
""";

	// Turns the (already blurred) alpha of the source into a coloured silhouette.
	const String cShadowBody = @"""
cbuffer ShadowConstants : register(b2)
{
	float4 gShadowColor;
};

float4 PSMain(PSInput input) : SV_TARGET
{
	float a = gTexture.Sample(gSampler, input.uv).a * gShadowColor.a;
	return float4(gShadowColor.rgb * a, a) * input.color;
}
""";

	static public void Build(String output, StringView body)
	{
		output.Append(cHeader);
		output.Append(body);
	}

	static public void BuildBlur(String output) => Build(output, cBlurBody);
	static public void BuildShadow(String output) => Build(output, cShadowBody);
}
