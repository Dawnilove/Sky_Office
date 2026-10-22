// 물: 연못은 가장자리가 밝고 가운데가 깊은 색 + 물가 거품 + 잔물결/반짝임
//     폭포(가파른 면)는 아래로 흐르는 줄무늬 + 가장자리를 넘는 곳의 하얀 거품
shader_type spatial;
render_mode cull_disabled;

uniform vec3 shallow : source_color = vec3(0.42, 0.72, 0.82);
uniform vec3 deep : source_color = vec3(0.13, 0.36, 0.55);
uniform vec3 foam : source_color = vec3(0.86, 0.94, 0.98);
uniform vec2 pond_center = vec2(0.0);
uniform vec2 pond_u = vec2(1.0, 0.0);   // 타원 장축 방향
uniform vec2 pond_v = vec2(0.0, 1.0);
uniform float pond_radius = 0.85;
uniform vec2 pond_scale = vec2(1.2, 0.9);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float steep = clamp(1.0 - abs(wnorm.y) * 1.3, 0.0, 1.0);
	float t = TIME;

	// 연못 안에서의 위치 (0 = 중심, 1 = 물가)
	vec2 rel = wpos.xz - pond_center;
	vec2 e = vec2(dot(rel, pond_u) / pond_scale.x, dot(rel, pond_v) / pond_scale.y) / pond_radius;
	float d = length(e);
	float depth = smoothstep(1.0, 0.15, d);                  // 물가 0 → 가운데 1
	vec3 base = mix(shallow, deep, depth);

	// 물가 거품: 가장자리를 따라 살짝 일렁이는 하얀 띠
	float wob = sin(atan(e.y, e.x) * 7.0 + t * 1.2) * 0.03;
	float shore = smoothstep(0.88 + wob, 0.99, d) * step(d, 1.05) * (1.0 - steep);

	// 잔물결 (아주 은은하게) + 햇빛 반짝임
	float ripple = smoothstep(0.94, 1.0, sin(d * 13.0 - t * 1.4)) * 0.12 * depth;
	float sparkle = smoothstep(0.975, 1.0, sin(wpos.x * 23.0 + t * 1.3) * sin(wpos.z * 19.0 - t * 1.1)) * (1.0 - steep);

	// 폭포: 아래로 흐르는 줄무늬 + 위쪽 가장자리 거품
	float fwob = sin(wpos.x * 9.0 + wpos.z * 7.0) * 1.4;
	float streak = smoothstep(0.7, 0.95, sin(wpos.y * 12.0 + t * 7.0 + fwob)) * steep;
	float lip = smoothstep(-0.35, 0.0, wpos.y) * steep;
	vec3 fall = mix(vec3(0.3, 0.58, 0.78), foam, clamp(streak + lip * 0.8, 0.0, 1.0));

	vec3 col = mix(base, foam, clamp(shore * 0.5 + ripple + sparkle * 0.6, 0.0, 1.0));
	ALBEDO = mix(col, fall, steep);
	ROUGHNESS = mix(0.08, 0.3, steep);
	SPECULAR = 0.7;
	EMISSION = ALBEDO * 0.05 + foam * sparkle * 0.3;
}
