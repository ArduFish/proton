#if !defined FOG_INCLUDED
#define FOG_INCLUDED

#include "utility/fastMath.glsl"

// This file is for analytical fog effects; for volumetric fog, see composite.fsh

// --------------------------------------
//  Fog effects common to all dimensions
// --------------------------------------

float getSphericalFog(float viewDist, float fogStartDistance, float fogDensity) {
	return exp2(-fogDensity * max0(viewDist - fogStartDistance));
}

float getBorderFog(vec3 scenePos, vec3 worldDir) {
#if defined WORLD_OVERWORLD
	float density = 1.0 - 0.2 * smoothstep(0.0, 0.25, worldDir.y);
#endif

	float fog = cubicLength(scenePos.xz) / far;
	      fog = exp2(-8.0 * pow8(fog * density));

	return fog;
}

void applyCommonFog(inout vec3 fragColor, vec3 scenePos, vec3 worldDir, bool isSky) {
	const vec3 lavaColor         = toRec2020(vec3(0.839, 0.373, 0.075)) * 2.0;
	const vec3 powderedSnowColor = toRec2020(vec3(0.957, 0.988, 0.988)) * 0.8;

	float fog;
	float viewDist = length(scenePos - gbufferModelView[3].xyz);

	// Blindness fog
	fog = getSphericalFog(viewDist, 2.0, 4.0 * blindness);
	fragColor *= fog;

	// Lava fog
	fog = getSphericalFog(viewDist, 0.33, 3.0 * float(isEyeInWater == 2));
	fragColor = mix(lavaColor, fragColor, fog);

	// Powdered snow fog
	fog = getSphericalFog(viewDist, 0.5, 5.0 * float(isEyeInWater == 3));
	fragColor = mix(powderedSnowColor, fragColor, fog);
}

//----------------------------------------------------------------------------//
#if defined WORLD_OVERWORLD

#include "atmosphere.glsl"

const vec3 caveFogColor = toRec2020(vec3(1.0)) * 0.0;

#if defined PROGRAM_DEFERRED3
vec3 getBorderFogColor(vec3 worldDir, float fog) {
	vec3 fogColor = illuminance[0] * atmosphereScattering(worldDir, sunDir)
	              + illuminance[1] * atmosphereScattering(worldDir, moonDir);

	worldDir.y = min(worldDir.y, -0.1);
	worldDir = normalize(worldDir);

#ifdef BORDER_FOG_HIDE_SUNSET_GRADIENT
	vec3 fogColorSunset = illuminance[0] * atmosphereScattering(worldDir, sunDir)
	                    + illuminance[1] * atmosphereScattering(worldDir, moonDir);

	float sunsetFactor = pulse(float(worldTime), 13000.0, 800.0, 24000.0)  // dusk
	                   + pulse(float(worldTime), 23000.0, 800.0, 24000.0); // dawn

	fogColor = mix(fogColor, fogColorSunset, sunsetFactor);
#endif

	return mix(fogColor, caveFogColor, biomeCave);
}
#endif

void applyFog(inout vec3 fragColor, vec3 scenePos, vec3 worldDir, bool isSky) {
	// Border fog

#if defined BORDER_FOG && defined PROGRAM_DEFERRED3
	if (!isSky) {
		float fog = getBorderFog(scenePos, worldDir);
		fragColor = mix(getBorderFogColor(worldDir, fog), fragColor, fog);
	}
#endif

	applyCommonFog(fragColor, scenePos, worldDir, isSky);
}

//----------------------------------------------------------------------------//
#elif defined WORLD_NETHER

void applyFog(inout vec3 fragColor) {

}

//----------------------------------------------------------------------------//
#elif defined WORLD_END

void applyFog(inout vec3 fragColor) {

}

#endif

#endif