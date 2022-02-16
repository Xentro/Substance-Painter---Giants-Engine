import lib-pbr.glsl
import lib-emissive.glsl
import lib-pom.glsl
import lib-sampler.glsl
import lib-alpha.glsl
import lib-utils.glsl

//: metadata {
//:   "mdl":"mdl::alg::materials::physically_metallic_roughness::physically_metallic_roughness"
//: }

#define WEAR_DEFAULT 0    // We want the background black
#define DIRT_DEFAULT 0    // We want the background black
#define ROUG_DEFAULT 0.6  // Painted steel?

//-------- Parameters ---------------------------------------------------//

//: param custom { "default": true, "label": "Enable Alpha Channel", "group": "Common Parameters", "description": "<html><head/><body><p>Activate usage of opacity map.</p></body></html>" }
uniform bool p_HasAlpha;

// Wear
//: param custom { "default": true, "label": "Show Wear", "group": "Wear Parameters" }
uniform bool p_showWear;
//: param custom { "default": 1.0, "label": "Wear Amount", "min": 0.0, "max": 1.0, "group": "Wear Parameters", "visible" : "input.p_showWear" }
uniform float p_wearLevel;

// Dirt
//: param custom { "default": true, "label": "Show Dirt", "group": "Dirt Parameters" }
uniform bool p_showDirt;
//: param custom { "default": 1.0, "label": "Dirt Amount", "min": 0.0, "max": 1.0, "group": "Dirt Parameters", "visible" : "input.p_showDirt" }
uniform float p_dirtLevel;

// Snow
//: param custom { "default": true, "label": "Show Snow", "group": "Snow Parameters" }
uniform bool p_showSnow;
//: param custom { "default": 1.0, "label": "Snow Amount", "min": 0.0, "max": 1.0, "group": "Snow Parameters", "visible" : "input.p_showSnow" }
uniform float p_snowLevel;

// Debug
//: param custom { "default": false, "label": "Debug Mode", "group": "Debug", "visible" : "true" }
uniform bool p_debugMode;
//: param custom { "default": 0.65, "label": "Roughness Intensity", "min": 0.0, "max": 1.0, "group": "Debug", "visible" : "input.p_debugMode" }
uniform float p_debugRoughness;
//: param custom { "default": 1.08, "label": "Roughness Intensity Wear", "min": 0.0, "max": 2.0, "group": "Debug", "visible" : "input.p_debugMode" }
uniform float p_debugRoughnessWear;
//: param custom { "default": 1.0, "label": "Metallic Intensity", "min": 0.0, "max": 1.0, "group": "Debug", "visible" : "input.p_debugMode" }
uniform float p_debugMetallic;
//: param custom { "default": [0.6, 0.6, 0.6], "label": "Wear Color", "widget": "color", "group": "Debug", "visible" : "false" }
uniform vec3 p_wearColor;
//: param custom { "default": [0.2, 0.14, 0.08], "label": "Dirt Color", "widget": "color", "group": "Debug", "visible" : "false" }
uniform vec3 p_dirtColor;
//: param custom { "default": [0.73, 0.7668, 0.8356], "label": "Snow Color", "widget": "color", "group": "Debug", "visible" : "false" }
uniform vec3 p_snowColor;
//: param custom {
//:   "default": 0,
//:   "label": "Debug channel",
//:   "widget": "combobox",
//:   "group": "Debug",
//:   "visible": "input.p_debugMode",
//:   "values": {
//:     "Base Color": 0,
//:     "Roughness": 1,
//:     "Metallic": 2,
//:     "AO": 3,
//:     "Wear": 4,
//:     "Dirt": 5,
//:     "Dirt (Processed)": 6,
//:     "Snow (Processed, Dirt Map)": 7
//:   }
//: }
uniform int p_debugChannel;


//-------- Channels ---------------------------------------------------//
//: param auto channel_basecolor
uniform SamplerSparse basecolor_tex;
//: param auto channel_roughness
uniform SamplerSparse roughness_tex;
//: param auto channel_metallic
uniform SamplerSparse metallic_tex;

//: param auto channel_user0
uniform SamplerSparse dirt_tex;
//: param auto channel_user1
uniform SamplerSparse wear_tex;


// Array data, Giants files needed here to go further
vec3 gDetailDiffuse;
vec3 gDetailSpecular = vec3(0.1, 1.0, 0.0);
vec3 gDetailNormal   = vec3(0.5, 0.5, 1.0);
vec3 gSnowSpecular   = vec3(0.1922, 0.8706, 0.0000);


//-------- Functions ---------------------------------------------------//
float sampleWithDefault(SamplerSparse sampler, SparseCoord coord, float defaultValue) {
	vec4 sampledValue = textureSparse(sampler, coord);
  	return sampledValue.r + (1.0 - sampledValue.g) * defaultValue;
}

float saturate(float value) {
    return clamp(value, 0.0, 1.0);
}
float linearstepFS(float a, float b, float x) {
    return saturate((x - a) / (b - a));
}
vec3 lerp(vec3 a, vec3 b, float w) {
  	return a + w * (b - a);
}
float lerp(float a, float b, float w) {
  	return a + w * (b - a);
}


void shade(V2F inputs)
{
	float wearLevel = 0;
	float dirtLevel = 0;
	float snowLevel = 0;

	if (p_showWear) { wearLevel = p_wearLevel; }
	if (p_showDirt) { dirtLevel = p_dirtLevel; }
	if (p_showSnow) { snowLevel = p_snowLevel; }
	
	if(p_debugMode) {
		if(p_debugChannel == 6) {
			dirtLevel = 1;
		} else if(p_debugChannel == 7) {
			snowLevel = 1;
		}
	}

	vec3 baseColor  = getBaseColor(basecolor_tex,       inputs.sparse_coord);
	float wear      = sampleWithDefault(wear_tex,       inputs.sparse_coord, WEAR_DEFAULT);
	float dirt      = sampleWithDefault(dirt_tex,       inputs.sparse_coord, DIRT_DEFAULT);
	float roughness = sampleWithDefault(roughness_tex,  inputs.sparse_coord, ROUG_DEFAULT);
	float metallic  = sampleWithDefault(metallic_tex,   inputs.sparse_coord, DEFAULT_METALLIC);

	float gWearMask = linearstepFS(1 - wearLevel, 1 - wearLevel + 0.05, wear);
	float mDirt     = linearstepFS(1 - dirtLevel, 1 - dirtLevel + 0.50, dirt);
	float mSnow     = linearstepFS(1 - snowLevel, 1 - snowLevel + 0.50, dirt);

	float gDirtMask = saturate((dirt * dirtLevel) + mDirt);
	float gSnowMask = saturate(mSnow + dirt * snowLevel);
	      gSnowMask = gSnowMask * gSnowMask * gSnowMask; // power of 3
	
	float dirtSnowCombined = 1.0 - saturate(gDirtMask + gSnowMask);

	gDetailSpecular = lerp(gDetailSpecular, vec3(0.85, 1.0, 1.0), gWearMask);
	gDetailSpecular = lerp(gDetailSpecular, vec3(1.0, 1.0, 1.0), gDirtMask);

	baseColor = lerp(baseColor, p_wearColor, gWearMask);

	vec3 diffuseColor = generateDiffuseColor(baseColor, gWearMask);
		 diffuseColor = lerp(diffuseColor, p_dirtColor * gDetailSpecular.g, gDirtMask);
	     diffuseColor = lerp(diffuseColor, p_snowColor, gSnowMask);

	metallic  = saturate(metallic + gWearMask) * p_debugMetallic;
	metallic *= dirtSnowCombined;
	roughness = saturate((roughness * p_debugRoughness) + (gWearMask * (1.0 - p_debugRoughnessWear)));

	float occlusion     = getAO(inputs.sparse_coord) * getShadowFactor();
	float specOcclusion = specularOcclusionCorrection(occlusion, metallic, roughness);
	vec3 specColor 	    = generateSpecularColor(dirtSnowCombined, baseColor, metallic);

	if( !p_debugMode ) {
		LocalVectors vectors = computeLocalFrame(inputs);

		if (p_HasAlpha) { alphaKill(inputs.sparse_coord); }

		// Apply parallax occlusion mapping if possible
		vec3 viewTS = worldSpaceToTangentSpace(getEyeVec(inputs.position), inputs);
		applyParallaxOffset(inputs, viewTS);

		// Feed parameters for a physically based BRDF integration
		emissiveColorOutput(pbrComputeEmissive(emissive_tex, inputs.sparse_coord));
		albedoOutput(diffuseColor);
		diffuseShadingOutput(occlusion * envIrradiance(vectors.normal));
		specularShadingOutput(specOcclusion * pbrComputeSpecular(vectors, specColor, roughness));
		sssCoefficientsOutput(getSSSCoefficients(inputs.sparse_coord));

	} else {
		vec3 result;

		if(p_debugChannel == 0) {
			result = baseColor;

		} else if(p_debugChannel == 1) {
			result = vec3(roughness);

		} else if(p_debugChannel == 2) {
			result = vec3(metallic);

		} else if(p_debugChannel == 3) {
			result = vec3(occlusion);

		} else if(p_debugChannel == 4) {
			result = vec3(wear);

		} else if(p_debugChannel == 5) {
			result = vec3(dirt);

		} else if(p_debugChannel == 6) {
			result = vec3(gDirtMask);

		} else if(p_debugChannel == 7) {
			result = vec3(gSnowMask);
		}
		
		diffuseShadingOutput(result);
	}
}