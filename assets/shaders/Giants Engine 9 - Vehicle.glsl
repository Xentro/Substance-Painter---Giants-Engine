import lib-pbr.glsl
import lib-emissive.glsl
import lib-pom.glsl
import lib-sampler.glsl
import lib-utils.glsl

//: metadata {
//:   "mdl":"mdl::alg::materials::physically_metallic_roughness::physically_metallic_roughness"
//: }

#define WEAR_DEFAULT 0    // We want the background black
#define DIRT_DEFAULT 0    // We want the background black
#define ROUG_DEFAULT 0.6  // Painted steel?

//-------- Parameters ---------------------------------------------------//
// Dirt
//: param custom { "default": true, "label": "Show Dirt", "group": "Dirt Parameters" }
uniform bool p_showDirt;
//: param custom { "default": 1.0, "label": "Dirt Amount", "min": 0.0, "max": 1.0, "group": "Dirt Parameters", "visible" : "input.p_showDirt" }
uniform float p_dirtLevel;

// Wear
//: param custom { "default": true, "label": "Show Wear", "group": "Wear Parameters" }
uniform bool p_showWear;
//: param custom { "default": 1.0, "label": "Wear Amount", "min": 0.0, "max": 1.0, "group": "Wear Parameters", "visible" : "input.p_showWear" }
uniform float p_wearLevel;

// Color Mask
//: param custom { "default": true, "label": "Use Color Mask", "group": "Color Mask", "description": "<html><head/><body><p>Using this will override the Base Color.</p></body></html>" }
uniform bool p_useColorMask;
//: param custom { "default": [0.8, 0.55, 0.05], "label": "Color Mat 0", "widget": "color", "group": "Color Mask", "visible" : "input.p_useColorMask" }
uniform vec3 p_colorID_0;
//: param custom { "default": [1.0, 0.10, 0.10], "label": "Color Mat 1", "widget": "color", "group": "Color Mask", "visible" : "input.p_useColorMask" }
uniform vec3 p_colorID_1;
//: param custom { "default": [0.10, 1.0, 0.10], "label": "Color Mat 2", "widget": "color", "group": "Color Mask", "visible" : "input.p_useColorMask" }
uniform vec3 p_colorID_2;
//: param custom { "default": [0.10, 0.10, 1.0], "label": "Color Mat 3", "widget": "color", "group": "Color Mask", "visible" : "input.p_useColorMask" }
uniform vec3 p_colorID_3;
//: param custom { "default": [1.0, 1.0, 0.10], "label": "Color Mat 4", "widget": "color", "group": "Color Mask", "visible" : "input.p_useColorMask" }
uniform vec3 p_colorID_4;
//: param custom { "default": [0.05, 0.05, 0.05], "label": "Color Mat 5", "widget": "color", "group": "Color Mask", "visible" : "input.p_useColorMask" }
uniform vec3 p_colorID_5;
//: param custom { "default": [1.0, 0.10, 1.0], "label": "Color Mat 6", "widget": "color", "group": "Color Mask", "visible" : "input.p_useColorMask" }
uniform vec3 p_colorID_6;
//: param custom { "default": [0.10, 1.0, 1.0], "label": "Color Mat 7", "widget": "color", "group": "Color Mask", "visible" : "input.p_useColorMask" }
uniform vec3 p_colorID_7;
// uniform bool p_colorID_active[8] = {false, false, false, false, false, false, false, false};

// Debug
//: param custom { "default": false, "label": "Debug Mode", "group": "Debug", "visible" : "true" }
uniform bool p_debugMode;
//: param custom { "default": 0.7, "label": "Debug Roughness Intensity", "min": 0.0, "max": 1.0, "group": "Debug", "visible" : "input.p_debugMode" }
uniform float p_debugRoughness;
//: param custom { "default": 1.0, "label": "Debug Metallic Intensity", "min": 0.0, "max": 1.0, "group": "Debug", "visible" : "input.p_debugMode" }
uniform float p_debugMetallic;
//: param custom { "default": [0.2, 0.14, 0.08], "label": "Dirt Color", "widget": "color", "group": "Debug", "visible" : "false" }
uniform vec3 p_dirtColor;
//: param custom { "default": [0.6, 0.6, 0.6], "label": "Wear Color", "widget": "color", "group": "Debug", "visible" : "false" }
uniform vec3 p_wearColor;
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
//:     "Dirt": 4,
//:     "Wear": 5
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
vec3 gDetailSpecular  = vec3(0.1, 1.0, 0.0);
vec3 gDetailNormal    = vec3(0.5, 0.5, 1.0);


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
  float dirtLevel = 0;
  float wearLevel = 0;

  if (p_showDirt) { dirtLevel = p_dirtLevel; }
  if (p_showWear) { wearLevel = p_wearLevel; }

  vec3 baseColor  = getBaseColor(basecolor_tex, inputs.sparse_coord);
  
  if (p_useColorMask) {
    vec3 colorTable[8] = {p_colorID_0, p_colorID_1, p_colorID_2, p_colorID_3, p_colorID_4, p_colorID_5, p_colorID_6, p_colorID_7};

    // UV below 0, Color Mask
    if (inputs.tex_coord.y < 0) {
      int index = clamp(int(inputs.tex_coord.x), 0, 7);
      baseColor = colorTable[index];
    }
  }

  float wear      = sampleWithDefault(wear_tex,       inputs.sparse_coord, WEAR_DEFAULT);
  float dirt      = sampleWithDefault(dirt_tex,       inputs.sparse_coord, DIRT_DEFAULT);
  float roughness = sampleWithDefault(roughness_tex,  inputs.sparse_coord, ROUG_DEFAULT);
  float metallic  = sampleWithDefault(metallic_tex,   inputs.sparse_coord, DEFAULT_METALLIC);

  float mWear  = linearstepFS(1.0 - wearLevel, 1.0 - wearLevel + 0.05, wear);
  float mDirt  = linearstepFS(1.0 - dirtLevel, 1.0 - dirtLevel + 0.50, dirt);
  float gDirt  = saturate((dirt * dirtLevel) + mDirt);

  metallic  = saturate(metallic + mWear) * p_debugMetallic;
  metallic *= 1.0 - gDirt; // Invert
  roughness = lerp(roughness, p_wearColor.r, mWear) * p_debugRoughness;
  baseColor = lerp(baseColor, p_wearColor, mWear);

  vec3 diffColor      = generateDiffuseColor(baseColor, metallic);
  float occlusion     = getAO(inputs.sparse_coord) * getShadowFactor();
  float specOcclusion = specularOcclusionCorrection(occlusion, metallic, roughness);

  diffColor *= gDetailSpecular.g;

  vec3 mDirtDiffuse  = p_dirtColor * gDetailSpecular.g;
  vec3 diffuseColor  = lerp(diffColor, mDirtDiffuse, gDirt);
  vec3 specColorDirt = generateSpecularColor(1.0 - gDirt, baseColor, metallic);

  if( !p_debugMode ) {
    LocalVectors vectors = computeLocalFrame(inputs);

    // Apply parallax occlusion mapping if possible
    vec3 viewTS = worldSpaceToTangentSpace(getEyeVec(inputs.position), inputs);
    applyParallaxOffset(inputs, viewTS);

    // Feed parameters for a physically based BRDF integration
    emissiveColorOutput(pbrComputeEmissive(emissive_tex, inputs.sparse_coord));
    albedoOutput(diffuseColor);
    diffuseShadingOutput(occlusion * envIrradiance(vectors.normal));
    specularShadingOutput(specOcclusion * pbrComputeSpecular(vectors, specColorDirt, roughness));
    sssCoefficientsOutput(getSSSCoefficients(inputs.sparse_coord));
  } else {
    vec3 result;

		if( p_debugChannel == 0 ) {
      result = baseColor;
		}
		else if( p_debugChannel == 1 ) {
			result = vec3(roughness);
		}
		else if( p_debugChannel == 2 ) {
			result = vec3(metallic);
		}
		else if( p_debugChannel == 3 ) {
			result = vec3(occlusion);
		}
    else if( p_debugChannel == 4 ) {
			result = vec3(dirt);
		}
    else if( p_debugChannel == 5 ) {
			result = vec3(wear);
		}
    
    diffuseShadingOutput(result);
  }
}