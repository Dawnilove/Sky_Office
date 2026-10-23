extends Node3D
## 사무실 고양이 (1.2 유니콘 단계 64, docs/v1_2/유니콘_초안.md 3장). 침대 ↔ 밥그릇 두 자리만 오가는 배경 생물:
## 대부분 잠 · 가끔 앉아 쉬기 · 밥 · 산책. 내 차례 · 조용히 모드 · 하루 끝 · 큰 연출 2명 이상이면 걷지 않고 침대에서 잠 (방해 방지 규칙 2 · 3)
## 모델 = animals/cat.glb (동작 Idle · Walk · Sleep · Eat — 앉기 동작은 아직 없어 Idle 로 대신). 털색 = 설치 솔트 해시 (같은 PC 는 늘 같은 고양이)

const MODEL := preload("res://assets/models/animals/cat.glb")
const COATS := ["e3a35c", "d8d3cb", "6b6a70", "3a3633"]
const SCALE := 0.7           ## 모델 (m) 배율 — 길이 약 0.4m
const SPEED := 0.45          ## 걷는 속도 (칸 / 초)
const FLOOR_Y := 0.04        ## 휴게 바닥 윗면 (칸)
const SLEEP_YAW := -90.0     ## 침대에서 왼쪽을 봄 (몸이 x 방향 → 서 있는 직원 자리 · 앉는 자리 z 와 안 겹침)

var layout
var bed := Vector2.ZERO
var bowl := Vector2.ZERO
var act := "sleep"
var until := 0.0
var hold_until := 0.0       ## 이 시각까지는 쓰다듬는 중 — 자던 자리 그대로
var last_walk := -1.0e18
var cfg: Dictionary = {}
var _anim: AnimationPlayer
var _tween: Tween


func setup(lay, c: Dictionary, salt: String) -> void:
	layout = lay
	cfg = c
	bed = lay.slots("cat_bed")[0].pos
	bowl = lay.slots("cat_bowl")[0].pos
	name = "Cat"
	var m := MODEL.instantiate() as Node3D
	m.scale = Vector3.ONE * SCALE
	add_child(m)
	_anim = m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for n in ["Idle", "Walk", "Sleep", "Eat"]:
		_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_paint(m, COATS[absi(salt.hash()) % COATS.size()])
	position = layout.m3(bed, FLOOR_Y)
	rotation_degrees.y = SLEEP_YAW
	_anim.play("Sleep")


func _paint(m: Node3D, coat: String) -> void:
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for sf in mesh.get_surface_count():
			var mat := mesh.surface_get_material(sf) as StandardMaterial3D
			if mat == null:
				continue
			var base := Color(coat)
			if mat.resource_name == "CatOrange":
				mat = mat.duplicate()
				mat.albedo_color = base
			elif mat.resource_name == "CatStripe":
				mat = mat.duplicate()
				mat.albedo_color = base.darkened(0.25)
			else:
				continue
			(mi as MeshInstance3D).set_surface_override_material(sf, mat)


## 걷거나 먹지 말고 자야 하는 때 (순수 함수 — 시험용): 내 차례 · 조용히 · 하루 끝 · 직원 큰 연출 2명 이상
static func calm(ctx: Dictionary) -> bool:
	return bool(ctx.get("turn", false)) or bool(ctx.get("quiet", false)) or bool(ctx.get("off", false)) or int(ctx.get("big_now", 0)) >= 2


## 다음 행동 (r = 0~1 난수). 걷기 · 밥은 마지막 걷기 뒤 walk_gap_s 가 지나야
static func pick(c: Dictionary, r: float, walk_ok: bool) -> String:
	var acts: Dictionary = c.get("acts", {})
	var total := 0.0
	var ws := []
	for a in acts:
		var w := 0.0 if (not walk_ok and a in ["stroll", "eat"]) else float(acts[a])
		ws.append([a, w])
		total += w
	var x := r * total
	for aw in ws:
		x -= float(aw[1])
		if x < 0.0:
			return str(aw[0])
	return "sleep"


func at_bed() -> bool:
	return position.distance_to(layout.m3(bed, FLOOR_Y)) < 0.05


func tick(now: float, ctx: Dictionary) -> void:
	if now < hold_until:
		return
	if calm(ctx):
		if act != "sleep":
			start("sleep", now)
		return
	if now < until:
		return
	start(pick(cfg, randf(), now - last_walk >= float(cfg.get("walk_gap_s", 300))), now)


## 쓰다듬는 동안 (t 까지) 자던 자리에서 가만히
func hold(t: float) -> void:
	hold_until = t


func start(a: String, now: float) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	act = a
	var span: Array = cfg.get("sleep_s", [60, 240])
	match a:
		"sleep":
			until = now + randf_range(float(span[0]), float(span[1]))
			_go(bed, SLEEP_YAW, "Sleep")
		"sit":
			until = now + randf_range(20.0, 60.0)
			_go(bed, SLEEP_YAW, "Idle")
		"eat":
			last_walk = now
			until = now + 14.0
			_go(bowl, SLEEP_YAW, "Eat")
		_:   # stroll
			last_walk = now
			until = now + 14.0
			_go(bowl, SLEEP_YAW, "Idle")


func _go(to: Vector2, yaw: float, anim: String) -> void:
	var dest: Vector3 = layout.m3(to, FLOOR_Y)
	var d: Vector2 = Vector2(dest.x - position.x, dest.z - position.z)
	if d.length() < 0.02:
		rotation_degrees.y = yaw
		_anim.play(anim, 0.3)
		return
	rotation_degrees.y = rad_to_deg(atan2(d.x, d.y))   # 모델 앞 = +z
	_anim.play("Walk", 0.2)
	_tween = create_tween()
	_tween.tween_property(self, "position", dest, d.length() / layout.unit_m / SPEED)
	_tween.tween_callback(func() -> void:
		_tween = null
		rotation_degrees.y = yaw
		_anim.play(anim, 0.3))
