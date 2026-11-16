## Natural-looking landscape materials (0.14): ground, foliage and water.
##
## They replace the flat "ground", "foliage" and "water" surfaces of Palette
## with small shaders that keep the vertex colours of the art but add what
## makes a landscape read as real from a city-builder camera:
## - ground: large patches of drier and lusher grass, medium blotches,
##   fine grain and, from Medium up, a grassy bump and the shadows of
##   passing clouds;
## - foliage: leafy clusters (noisy normals and light/dark blotches) on
##   the round crowns, sunlit tops and shaded undersides, slight colour
##   variation between trees, and on High a gentle sway in the wind;
## - water: rippling normals that pick up the sky and the sun glint.
##
## Everything comes from two small tileable textures made at start-up, so
## there are no extra files, and the cost per pixel is a few texture reads.
## Expensive parts are switched by a "quality" uniform (Graphics level):
## Low keeps colour variation only.
class_name Landscape
extends RefCounted

static var _noise: ImageTexture
static var _waves: ImageTexture
static var _shaders := {}

const COMMON := """
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D occlusion_tex : filter_linear, repeat_disable;
uniform float ao_light_affect = 0.35;
uniform float quality = 2.0;
uniform float rim_amount = 0.0;
varying vec3 wpos;
varying vec3 wnor;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}
"""

const GROUND := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;
%s
uniform float cloud_shadow = 0.0;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) {
		base = to_linear(base);
	}
	bool top = wnor.y > 0.5;
	vec2 p = top ? wpos.xz : vec2(wpos.x + wpos.z, wpos.y * 2.0);
	float macro = texture(noise_tex, p * (1.0 / 95.0)).r;
	float mid = texture(noise_tex, p * (1.0 / 21.0) + vec2(0.37, 0.11)).g;
	float fine = texture(noise_tex, p * (1.0 / 2.6)).b;
	// Green surfaces (grass) drift between lush and sun-dried patches; soil,
	// sand and rock only get light and dark blotches.
	float green = clamp((base.g - max(base.r, base.b)) * 9.0, 0.0, 1.0);
	float dry = smoothstep(0.28, 0.78, macro);
	// Real grass seen from above is less saturated than paint: pull it
	// towards olive, then drift between lush and sun-dried.
	float luma = dot(base, vec3(0.3, 0.55, 0.15));
	vec3 olive = mix(vec3(luma), base, 0.62) * vec3(1.08, 1.0, 0.78);
	base = mix(base, olive, green);
	vec3 tint = mix(vec3(0.84, 0.97, 0.88), vec3(1.14, 1.05, 0.78), dry);
	vec3 col = base * mix(vec3(0.92 + 0.16 * dry), tint, green);
	col *= 0.84 + 0.32 * mid;
	col *= 0.88 + 0.24 * fine;
	vec3 n = wnor;
	if (quality > 0.5 && top) {
		// A grassy bump: the slope of a fine noise tilts the normal.
		vec2 q = p * (1.0 / 0.9);
		float h0 = texture(noise_tex, q).a;
		float hx = texture(noise_tex, q + vec2(0.012, 0.0)).a;
		float hz = texture(noise_tex, q + vec2(0.0, 0.012)).a;
		n = normalize(wnor + vec3(h0 - hx, 0.0, h0 - hz) * (2.2 + 2.0 * green));
		col *= 0.9 + 0.2 * h0;
		// Shadows of passing clouds, drifting with the wind.
		float c = texture(noise_tex, (p + vec2(TIME * 1.2, TIME * 0.35)) * (1.0 / 150.0) + vec2(0.5, 0.2)).r;
		col *= 1.0 - cloud_shadow * 0.32 * smoothstep(0.52, 0.72, c);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = 0.96;
	SPECULAR = 0.22;
	AO = texture(occlusion_tex, UV2).r;
	AO_LIGHT_AFFECT = ao_light_affect;
	RIM = rim_amount;
	RIM_TINT = 0.6;
}
"""

const FOLIAGE := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;
%s
uniform float wind = 1.0;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (quality > 1.5) {
		// The upper parts of each crown sway a few centimetres.
		float sway = 1.0 - UV2.x;
		float ph = dot(w.xz, vec2(0.23, 0.17));
		VERTEX += vec3(sin(TIME * 1.4 + ph), 0.0, cos(TIME * 1.1 + ph * 1.3)) * 0.045 * sway * wind;
	}
	wpos = w;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) {
		base = to_linear(base);
	}
	// Leaf clusters: two noise reads across the crown, on its own slant so
	// that round crowns break up into clumps.
	vec2 a = vec2(wpos.x + wpos.y * 0.6, wpos.z - wpos.y * 0.4) * 0.55;
	vec2 b = vec2(wpos.z + wpos.y * 0.7, wpos.x + wpos.y * 0.3) * 1.3;
	float n1 = texture(noise_tex, a).b;
	float n2 = texture(noise_tex, b).a;
	float clumps = n1 * 0.6 + n2 * 0.4;
	// Each tree a slightly different green, some yellower, some bluer.
	float hue = texture(noise_tex, wpos.xz * (1.0 / 37.0)).g;
	vec3 col = base * mix(vec3(0.86, 0.98, 1.02), vec3(1.14, 1.04, 0.78), hue);
	// Sunlit top, shaded underside, lighter leaf tips in the clumps.
	float up = wnor.y * 0.5 + 0.5;
	col *= mix(0.62, 1.12, up);
	col *= 0.7 + 0.6 * clumps;
	vec3 n = wnor;
	if (quality > 0.5) {
		vec3 jitter = vec3(n1 - 0.5, n2 - 0.5, texture(noise_tex, a.yx * 1.7).r - 0.5);
		n = normalize(wnor + jitter * 1.6);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = 0.82;
	SPECULAR = 0.3;
	AO = texture(occlusion_tex, UV2).r;
	AO_LIGHT_AFFECT = ao_light_affect;
	RIM = rim_amount;
	RIM_TINT = 0.7;
}
"""

const WATER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
%s
uniform sampler2D wave_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 sky_tint : source_color = vec4(0.62, 0.74, 0.86, 1.0);

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) {
		base = to_linear(base);
	}
	vec2 p = wpos.xz;
	vec2 g = vec2(0.0);
	if (wnor.y > 0.5) {
		vec2 w1 = texture(wave_tex, p * (1.0 / 7.0) + TIME * vec2(0.021, 0.013)).xy * 2.0 - 1.0;
		vec2 w2 = texture(wave_tex, p * (1.0 / 3.3) - TIME * vec2(0.017, -0.027)).xy * 2.0 - 1.0;
		g = w1 * 0.6 + w2 * 0.4;
		if (quality > 1.5) {
			vec2 w3 = texture(wave_tex, p * (1.0 / 1.1) + TIME * vec2(-0.05, 0.04)).xy * 2.0 - 1.0;
			g += w3 * 0.3;
		}
	}
	vec3 n = normalize(vec3(g.x * 0.6, 1.0, g.y * 0.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// Water is dark where it lets you see in and mirrors the sky where the
	// ripples turn it away from the eye (Schlick's Fresnel term). The
	// camera looks down steeply, so the ripples do most of the work.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = 0.06 + 0.94 * pow(1.0 - facing, 5.0);
	float shade = texture(noise_tex, p * (1.0 / 18.0)).g;
	vec3 col = base * (0.5 + 0.25 * shade);
	col = mix(col, sky_tint.rgb * 0.8, clamp(fresnel * 3.0 + length(g) * 0.12, 0.0, 0.75));
	ALBEDO = col;
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	AO = texture(occlusion_tex, UV2).r;
	AO_LIGHT_AFFECT = 0.0;
}
"""


static func is_landscape(kind: String) -> bool:
	return kind == "ground" or kind == "foliage" or kind == "water"


## A new material of one of the three kinds.
static func material(kind: String) -> ShaderMaterial:
	if not _shaders.has(kind):
		var code: String = {"ground": GROUND, "foliage": FOLIAGE, "water": WATER}[kind]
		var sh := Shader.new()
		sh.code = code % COMMON
		_shaders[kind] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[kind]
	m.set_shader_parameter("noise_tex", noise_texture())
	m.set_shader_parameter("occlusion_tex", Palette.occlusion_texture())
	if kind == "water":
		m.set_shader_parameter("wave_tex", wave_texture())
	return m


## Matches the Graphics level (see Palette.set_style).
static func style(m: ShaderMaterial, kind: String, tier: int) -> void:
	m.set_shader_parameter("quality", float(tier))
	m.set_shader_parameter("ao_light_affect", [0.7, 0.5, 0.35][tier])
	var rim := 0.0
	if tier > 0 and kind != "water":
		rim = 0.25 if kind == "ground" else 0.4
	m.set_shader_parameter("rim_amount", rim)


## Shadow strength of the drifting clouds on the ground (0 at night).
static func set_cloud_shadow(m: Material, amount: float) -> void:
	if m is ShaderMaterial:
		m.set_shader_parameter("cloud_shadow", amount)


## Sky colour mixed into the ripples, from the day/night cycle.
static func set_sky(m: Material, color: Color) -> void:
	if m is ShaderMaterial:
		m.set_shader_parameter("sky_tint", color)


## Four tileable noises in one texture: R broad patches, G medium blotches,
## B fine grain, A small bumps.
static func noise_texture() -> ImageTexture:
	if _noise:
		return _noise
	var size := 256
	var specs := [[3, 0.008, 4], [17, 0.02, 4], [29, 0.06, 3], [41, 0.11, 2]]
	var layers: Array[PackedByteArray] = []
	for s in specs:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = s[0]
		n.frequency = s[1]
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = s[2]
		var img := n.get_seamless_image(size, size)
		img.convert(Image.FORMAT_L8)
		layers.append(img.get_data())
	var out := PackedByteArray()
	out.resize(size * size * 4)
	for i in size * size:
		out[i * 4] = layers[0][i]
		out[i * 4 + 1] = layers[1][i]
		out[i * 4 + 2] = layers[2][i]
		out[i * 4 + 3] = layers[3][i]
	var img := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, out)
	img.generate_mipmaps()
	_noise = ImageTexture.create_from_image(img)
	return _noise


## Tileable ripple normals for water.
static func wave_texture() -> ImageTexture:
	if _waves:
		return _waves
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = 5
	n.frequency = 0.03
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	var img := n.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(6.0)
	img.generate_mipmaps()
	_waves = ImageTexture.create_from_image(img)
	return _waves
