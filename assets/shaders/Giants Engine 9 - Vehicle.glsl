import lib-pbr.glsl
import lib-emissive.glsl
import lib-pom.glsl
import lib-sampler.glsl
import lib-utils.glsl

//: metadata {
//:   "mdl":"mdl::alg::materials::physically_metallic_roughness::physically_metallic_roughness"
//: }


//-------- Functions ---------------------------------------------------//
vec3 getBaseColorWithDefault(vec4 sampledValue, float defaultValue)
{
  return sampledValue.rgb + defaultValue * (1.0 - sampledValue.a);
}
vec3 getBaseColorWithDefault(SamplerSparse sampler, SparseCoord coord, float defaultValue)
{
  return getBaseColorWithDefault(textureSparse(sampler, coord), defaultValue);
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


//-------- Parameters ---------------------------------------------------//
//: param custom { "default": true, "label": "Enable", "group": "Dirt Parameters" }
uniform bool p_showDirt;
//: param custom { "default": 1.0, "label": "Dirt Amount", "min": 0.0, "max": 1.0, "group": "Dirt Parameters" }
uniform float p_dirtLevel;
//: param custom { "default": [0.2, 0.14, 0.08], "label": "Dirt Color", "widget": "color", "group": "Dirt Parameters" }
uniform vec3 p_dirtColor;

//: param custom { "default": true, "label": "Enable", "group": "Wear Parameters" }
uniform bool p_showWear;
//: param custom { "default": 1.0, "label": "Wear Amount", "min": 0.0, "max": 1.0, "group": "Wear Parameters" }
uniform float p_wearLevel;
//: param custom { "default": [0.6, 0.6, 0.6], "label": "Wear Color", "widget": "color", "group": "Wear Parameters" }
uniform vec3 p_wearColor;

//: param custom { "default": true, "label": "Enable", "group": "Color Mask" }
uniform bool p_useColorMask;
//: param custom { "default": [0.8, 0.55, 0.05], "label": "Color ID 1", "widget": "color", "group": "Color Mask" }
uniform vec3 p_colorID_0;
//: param custom { "default": [1.0, 0.10, 0.10], "label": "Color ID 2", "widget": "color", "group": "Color Mask" }
uniform vec3 p_colorID_1;
//: param custom { "default": [0.10, 1.0, 0.10], "label": "Color ID 3", "widget": "color", "group": "Color Mask" }
uniform vec3 p_colorID_2;
//: param custom { "default": [0.10, 0.10, 1.0], "label": "Color ID 4", "widget": "color", "group": "Color Mask" }
uniform vec3 p_colorID_3;
//: param custom { "default": [1.0, 1.0, 0.10], "label": "Color ID 5", "widget": "color", "group": "Color Mask" }
uniform vec3 p_colorID_4;
//: param custom { "default": [0.05, 0.05, 0.05], "label": "Color ID 6", "widget": "color", "group": "Color Mask" }
uniform vec3 p_colorID_5;
//: param custom { "default": [1.0, 0.10, 1.0], "label": "Color ID 7", "widget": "color", "group": "Color Mask" }
uniform vec3 p_colorID_6;
//: param custom { "default": [0.10, 1.0, 1.0], "label": "Color ID 8", "widget": "color", "group": "Color Mask" }
uniform vec3 p_colorID_7;

// Debug
//: param custom { "default": false, "label": "Debug Mode", "group": "Debug" }
uniform bool p_debugMode;
//: param custom {
//:   "default": 0,
//:   "label": "Debug channel",
//:   "widget": "combobox",
//:   "group": "Debug",
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
//: param custom { "default": 0.7, "label": "Roughness Intensity", "min": 0.0, "max": 1.0, "group": "Debug" }
uniform float p_debugRoughness;
//: param custom { "default": 1.0, "label": "Metallic Intensity", "min": 0.0, "max": 1.0, "group": "Debug" }
uniform float p_debugMetallic;


//-------- Channels ---------------------------------------------------//
//: param auto channel_basecolor
uniform SamplerSparse basecolor_tex;
//: param auto channel_roughness
uniform SamplerSparse roughness_tex;
//: param auto channel_metallic
uniform SamplerSparse metallic_tex;
//: param auto channel_specularlevel
uniform SamplerSparse specularlevel_tex;

//: param auto channel_user0
uniform SamplerSparse dirt_tex;
//: param auto channel_user1
uniform SamplerSparse wear_tex;


// Array data, Giants files needed here to go further
vec3 gDetailDiffuse;
vec3 gDetailSpecular  = vec3(0.1, 1.0, 0.0);
vec3 gDetailNormal    = vec3(0.5, 0.5, 1.0);


void shade(V2F inputs)
{
  float dirtLevel = 0;
  float wearLevel = 0;

  if (p_showDirt) { dirtLevel = p_dirtLevel; }
  if (p_showWear) { wearLevel = p_wearLevel; }

  // Apply parallax occlusion mapping if possible
  vec3 viewTS = worldSpaceToTangentSpace(getEyeVec(inputs.position), inputs);
  applyParallaxOffset(inputs, viewTS);

  vec3 baseColor  = getBaseColor(basecolor_tex, inputs.sparse_coord);
  
  if (p_useColorMask) {
    vec3 colorTable[8] = {p_colorID_0, p_colorID_1, p_colorID_2, p_colorID_3, p_colorID_4, p_colorID_5, p_colorID_6, p_colorID_7};

    // UV below 0, Color Mask
    if (inputs.tex_coord.y < 0) {
      int id = clamp(int(inputs.tex_coord.x), 0, 7);
      baseColor = colorTable[id];
    }
  }
  vec3 wearMask   = getBaseColorWithDefault(wear_tex, inputs.sparse_coord, 0.0);
  vec3 dirtMask   = getBaseColorWithDefault(dirt_tex, inputs.sparse_coord, 0.0);
  float roughness = getRoughness(roughness_tex, inputs.sparse_coord);
  float metallic  = getMetallic(metallic_tex, inputs.sparse_coord);

  float mWear  = linearstepFS(1.0 - wearLevel, 1.0 - wearLevel + 0.05, wearMask.r);
  float mDirt  = linearstepFS(1.0 - dirtLevel, 1.0 - dirtLevel + 0.5, dirtMask.r);
  float gDirt  = saturate((dirtMask.r * dirtLevel) + mDirt);

  metallic  = saturate(metallic + mWear) * p_debugMetallic;
  metallic *= 1.0 - gDirt; // Invert
  roughness = lerp(roughness, p_wearColor.r, mWear) * p_debugRoughness;
  baseColor = lerp(baseColor, p_wearColor, mWear);

  vec3 diffColor = generateDiffuseColor(baseColor, metallic);

  float occlusion     = getAO(inputs.sparse_coord) * getShadowFactor();
  float specOcclusion = specularOcclusionCorrection(occlusion, metallic, roughness);

  diffColor *= gDetailSpecular.g;

  vec3 mDirtDiffuse  = p_dirtColor * gDetailSpecular.g;
  vec3 diffuseColor  = lerp(diffColor, mDirtDiffuse, gDirt);
  vec3 specColorDirt = generateSpecularColor(1 - gDirt, baseColor, metallic);

  if( !p_debugMode ) {
    LocalVectors vectors = computeLocalFrame(inputs);

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
			result = vec3(dirtMask.r, dirtMask.r, dirtMask.r);
		}
    else if( p_debugChannel == 5 ) {
			result = vec3(wearMask.r, wearMask.r, wearMask.r);
		}
    
    diffuseShadingOutput(result);
  }
}
