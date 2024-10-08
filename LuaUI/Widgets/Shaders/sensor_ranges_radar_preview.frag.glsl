#version 420
// Beherith (mysterme@gmail.com) claims copyright on this file. He gives the Zero-K team permission to
// use this for ZK but he would be unhappy if it were copied further without asking him, so best to ask.

#line 20000

uniform vec4 radarcenter_range;  // x y z range
uniform float resolution;  // how many steps are done

uniform sampler2D heightmapTex;

//__ENGINEUNIFORMBUFFERDEFS__

//__DEFINES__
in DataVS {
	vec4 worldPos; // w = range
	vec4 centerposrange;
	vec4 blendedcolor;
	float worldscale_circumference;
};

out vec4 fragColor;

void main() {
	vec2 mymin = min(worldPos.xz,mapSize.xy - worldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);
	if (inboundsness < 0)
		discard;


	fragColor.rgba = blendedcolor.rgba;

	vec2 toedge = centerposrange.xz - worldPos.xz;

	float angle = atan(toedge.y/toedge.x);

	angle = (angle + 1.56)/3.14;

	float angletime = fract(angle - timeInfo.x* 0.033);

	angletime = 0.5; // no spinny for now

	angle = clamp(angletime, 0.2, 0.8);

	fragColor.a = min(smoothstep(0,1,fragColor.a), 1.0 ); // - clamp(inboundsness*(-0.1),0.0,1.0));



	if (length(worldPos.xz - radarcenter_range.xz) > radarcenter_range.w) fragColor.a = 0.0;

	fragColor.a = fragColor.a * angle * 0.85;
	
	float pulse = 1 + sin(-2.0 * sqrt(length(toedge)) + 0.033 * timeInfo.x);
	pulse *= pulse * 0.5;
	fragColor.a = mix(fragColor.a, fragColor.a * pulse, 0.10);
}