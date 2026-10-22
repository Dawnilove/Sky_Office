extends RefCounted
## 섬의 움직이는 효과 모음: 굴뚝 연기, 모닥불(불꽃·불씨·깜빡이는 빛), 폭포 물보라
## 모두 GPU 파티클 → CPU 부담 거의 없음

const WATER_SHADER := preload("res://shaders/water.gdshader")


## 굴뚝 연기: 둥근 연기 덩어리가 올라가며 커지고 옅어짐 (바람에 살짝 밀림)
static func smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 14
	p.lifetime = 4.5
	p.preprocess = 4.5
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 10.0
	m.initial_velocity_min = 0.22
	m.initial_velocity_max = 0.32
	m.gravity = Vector3(0.07, 0.03, 0.02)
	m.scale_min = 0.11
	m.scale_max = 0.16
	m.scale_curve = _curve_tex([Vector2(0, 0.5), Vector2(0.4, 1.2), Vector2(1, 2.0)])
	m.color_ramp = _grad_tex([Color(0.42, 0.41, 0.44, 0.0), Color(0.42, 0.41, 0.44, 0.85),
			Color(0.58, 0.58, 0.62, 0.45), Color(0.7, 0.7, 0.74, 0.0)], [0.0, 0.08, 0.6, 1.0])
	m.angle_min = 0
	m.angle_max = 360
	p.process_material = m
	p.draw_pass_1 = _puff_mesh(false, 1.0)
	p.visibility_aabb = AABB(Vector3(-0.6, -0.2, -0.6), Vector3(1.6, 2.4, 1.4))
	return p


## 모닥불: 불꽃(위로 빠르게, 작아지며 사라짐) + 불씨(작은 점이 높이 날아오름)
static func fire() -> Node3D:
	var root := Node3D.new()
	root.name = "Fire"
	root.position.y = 0.1   # 통나무 사이로 보이게 살짝 위에서
	# 바깥 불꽃: 주황 → 빨강, 위로 솟으며 가늘어짐
	root.add_child(_flame_layer(12, 0.6, 0.12, Vector2(0.25, 0.45), Vector2(0.15, 0.2), 1.7,
			[Color(1.0, 0.62, 0.15, 0.95), Color(0.95, 0.32, 0.07, 0.85), Color(0.6, 0.12, 0.04, 0.0)]))
	# 안쪽 불꽃: 밝은 노랑 → 주황 (더 작고 빠름)
	root.add_child(_flame_layer(10, 0.45, 0.06, Vector2(0.3, 0.5), Vector2(0.1, 0.13), 2.3,
			[Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.75, 0.3, 0.9), Color(1.0, 0.45, 0.1, 0.0)]))

	var sp := GPUParticles3D.new()
	sp.amount = 6
	sp.lifetime = 1.6
	sp.preprocess = 1.6
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.12
	sm.direction = Vector3.UP
	sm.spread = 25.0
	sm.initial_velocity_min = 0.5
	sm.initial_velocity_max = 0.9
	sm.gravity = Vector3(0.05, 0.1, 0)
	sm.scale_min = 0.012
	sm.scale_max = 0.02
	sm.color_ramp = _grad_tex([Color(1, 0.8, 0.4, 1), Color(1, 0.4, 0.1, 0)], [0.0, 1.0])
	sp.process_material = sm
	sp.draw_pass_1 = _puff_mesh(true, 3.0)
	sp.visibility_aabb = AABB(Vector3(-0.6, -0.1, -0.6), Vector3(1.2, 2.0, 1.2))
	root.add_child(sp)
	return root


## 떨어지는 낙엽: 나무 위에서 가끔 한 장씩 팔랑이며 내려옴
static func leaves(colors: Array, top: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Leaves"
	p.amount = 3
	p.lifetime = 5.5
	p.preprocess = 5.5
	p.position.y = top
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.45, 0.15, 0.45)
	m.direction = Vector3(1, -0.3, 0.4)
	m.spread = 60.0
	m.initial_velocity_min = 0.03
	m.initial_velocity_max = 0.08
	m.gravity = Vector3(0.04, -0.11, 0.02)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.5
	m.turbulence_noise_scale = 1.5
	m.angular_velocity_min = -160.0
	m.angular_velocity_max = 160.0
	m.particle_flag_rotate_y = true
	m.scale_min = 0.8
	m.scale_max = 1.2
	var g := Gradient.new()   # 시작 색: 나무 잎 색 중 하나 (무작위)
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.34, 0.67])
	g.colors = PackedColorArray(colors)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_initial_ramp = gt
	m.color_ramp = _grad_tex([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.85, 1.0])
	p.process_material = m
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.006, 0.045)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3(-0.9, -top - 0.1, -0.9), Vector3(1.8, top + 0.4, 1.8))
	return p


## 폭포 아래 물보라: 하얀 물방울 덩어리가 아래·바깥으로 흩어지며 사라짐
static func mist(outward: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Mist"
	p.amount = 10
	p.lifetime = 1.2
	p.preprocess = 1.2
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.12
	m.direction = (outward.normalized() * 1.2 + Vector3.DOWN).normalized()
	m.spread = 30.0
	m.initial_velocity_min = 0.2
	m.initial_velocity_max = 0.35
	m.gravity = Vector3(0, -0.5, 0)
	m.scale_min = 0.05
	m.scale_max = 0.08
	m.scale_curve = _curve_tex([Vector2(0, 0.7), Vector2(1, 1.5)])
	m.color_ramp = _grad_tex([Color(0.95, 0.98, 1.0, 0.0), Color(0.95, 0.98, 1.0, 0.7), Color(1, 1, 1, 0.0)], [0.0, 0.15, 1.0])
	p.process_material = m
	p.draw_pass_1 = _puff_mesh(true, 1.0)
	p.visibility_aabb = AABB(Vector3(-0.7, -0.9, -0.7), Vector3(1.4, 1.1, 1.4))
	return p


## 물 재질 (연못 깊이색·물가 거품 + 폭포 줄무늬). meta: water_meta.json 내용
static func water_material(meta: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	var v2 := func(a: Array) -> Vector2: return Vector2(a[0], a[1])
	mat.set_shader_parameter("pond_center", v2.call(meta.center))
	mat.set_shader_parameter("pond_u", v2.call(meta.u))
	mat.set_shader_parameter("pond_v", v2.call(meta.v))
	mat.set_shader_parameter("pond_radius", float(meta.radius))
	mat.set_shader_parameter("pond_scale", Vector2(meta.su, meta.sv))
	return mat


## 모닥불 빛 깜빡임 (OmniLight3D 에 붙여 씀)
class Flicker extends Node:
	var light: OmniLight3D
	var base := 2.6
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		light.light_energy = base * (0.85 + 0.1 * sin(_t * 13.0) + 0.07 * sin(_t * 23.0 + 1.3) + 0.05 * sin(_t * 7.0))


# ------------------------------------------------------------------ 내부 도우미
## 불꽃 한 겹: 위로 뾰족한 원뿔 입자 (회전 없이 곧게 솟음)
static func _flame_layer(amount: int, life: float, radius: float, vel: Vector2, size: Vector2,
		energy: float, ramp: Array) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = 1.0
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = radius
	m.direction = Vector3.UP
	m.spread = 8.0
	m.initial_velocity_min = vel.x
	m.initial_velocity_max = vel.y
	m.gravity = Vector3(0, 0.5, 0)
	m.scale_min = size.x
	m.scale_max = size.y
	m.scale_curve = _curve_tex([Vector2(0, 0.55), Vector2(0.3, 1.0), Vector2(1, 0.15)])
	m.color_ramp = _grad_tex(ramp, [0.0, 0.5, 1.0])
	p.process_material = m
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.75
	mesh.height = 2.6
	mesh.radial_segments = 5
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(energy, energy, energy)   # 1보다 밝게 → 글로우
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3(-0.4, -0.1, -0.4), Vector3(0.8, 1.0, 0.8))
	return p



static func _puff_mesh(glow: bool, energy: float, stretch := Vector3.ONE) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0 * stretch.x
	mesh.height = 2.0 * stretch.y
	mesh.radial_segments = 7
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(energy, energy, energy)   # 1보다 밝게 → 글로우 효과
	mesh.material = mat
	return mesh


static func _curve_tex(points: Array) -> CurveTexture:
	var c := Curve.new()
	for pt in points:
		c.add_point(pt)
	var ct := CurveTexture.new()
	ct.curve = c
	return ct


static func _grad_tex(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt
