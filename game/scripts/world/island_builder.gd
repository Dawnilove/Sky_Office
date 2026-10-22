extends Node3D
## 배치 데이터(JSON)를 읽어 섬 위에 모델을 놓는다 + 걸을 수 있는 땅 · 길찾기 · 확장 섬(증축).
## 하늘 오피스: 섬 · 나무 · 풀만 놓고, 사무실 (구역 · 책상) 은 office.gd 가 zones.json 대로 얹음
## M2: 지름 14 회색 상자 시험용으로 섬을 scale_k 배 늘림 (진짜 증축 섬은 1.1~)

const MODEL_DIR := "res://assets/models/%s.glb"
const Effects := preload("res://scripts/world/effects.gd")
## 나무 종류별 떨어지는 잎 색 — 하늘 오피스는 주황 · 노랑 대신 차분한 초록 · 갈색 (노랑 예약, PLAN 3-3)
const LEAF_COLORS := {
	"tree_0": ["6f8a45", "7d9650", "7a6a4e"],
	"tree_1": ["5e7f3c", "6c8c46", "6e5e46"],
	"tree_2": ["728c4a", "809a55", "7a6a4e"],
	"tree_3": ["6a8a48", "78984f", "6e5e46"],
}
## 연못 정보 (Blender 생성기가 함께 내보냄: 중심·반경·타원 축)
const WATER_META := "res://assets/models/water_meta.json"
## 밟고 지나갈 수 있는 소품 (걷기 장애물에서 제외)
const WALK_THROUGH := ["island", "water", "stepping_stone", "grass_tuft"]
## 걸어 다닐 수 있는 최대 반경 (섬 가장자리 여유)
const WALK_RADIUS := 4.0
## 확장 섬 위치·다리 끝점 (Blender 생성기가 함께 내보냄)
const ISLETS_META := "res://assets/models/islets.json"
## 길찾기 격자
const NAV_CELL := 0.1   ## 좁은 틈도 지나가게 촘촘히 (땅 칸만 장애물 검사 → 만드는 데 수십 ms)
const NAV_RECT := Rect2(-10.0, -7.0, 20.0, 14.0)

## 모델별 조명 (위치는 모델 기준)
const LIGHTS := {
	"lamp": {"offset": Vector3(0, 1.6, 0), "color": Color("ffc062"), "energy": 1.6, "range": 3.2},
	"campfire": {"offset": Vector3(0, 0.45, 0), "color": Color("ff7a2a"), "energy": 2.6, "range": 4.0},
	"crystal_lamp": {"offset": Vector3(0, 1.1, 0), "color": Color("7fe3ff"), "energy": 1.4, "range": 3.0},
}

signal item_placed(node: Node3D, asset: String)

var islets_added: Array[int] = []   ## 붙어 있는 확장 섬 번호 (0, 1)
var _cache := {}
var _occupied: Array = []   # [Vector2 위치, 반경] — 풀 흩뿌리기 제외 영역
var _solid: Array = []      # [Vector2 위치, 반경] — 지나갈 수 없는 영역
var _islet_meta: Array = []
var _solid_rects: Array[Rect2] = []     # 지나갈 수 없는 사각형 (벽 · 책상 · 창구, 월드 미터 [x, z])
var _occupied_rects: Array[Rect2] = []  # 풀을 흩뿌리지 않는 사각형 (구역 바닥)
var _walk_rects: Array[Rect2] = []      # 섬 밖이지만 걸을 수 있는 곳 (승강장 부두)
var scale_k := 1.0   ## 섬 배율 = 지름 / 10 (build 전에 정함)
var walk_circle := true   ## false = 둥근 섬 땅이 없음 (v2.4 받침형) → 걷는 곳은 add_walk_rect 로만
var _scatter_cfg: Array = []


## 섬 · 소품 놓기. 풀 흩뿌리기는 사무실을 얹은 뒤 finish() 에서 (구역 바닥을 피하게)
func build(layout_path: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layout_path))
	for item in data.get("items", []):
		_place_item(item)
	for ex in data.get("exclude", []):
		_occupied.append([_v2(ex.pos) * scale_k, float(ex.radius)])
		_solid.append([_v2(ex.pos) * scale_k, float(ex.radius)])
	_scatter_cfg = data.get("scatter", [])


func finish() -> void:
	for sc in _scatter_cfg:
		_scatter(sc)
	# 구름은 뺌 (실내 회사 장면, 사용자 2026-10-16 — 1.1 창밖 연출 때 다시)


func _model(asset: String) -> Node3D:
	if not _cache.has(asset):
		_cache[asset] = load(MODEL_DIR % asset)
	return _cache[asset].instantiate()


func _place_item(item: Dictionary) -> Node3D:
	var node := _model(item.asset)
	var p := _v2(item.pos) * scale_k   # 소품 자리는 섬 배율을 따라감 (비율 자리)
	node.position = Vector3(p.x, ground_height(p) if not islets_added.is_empty() else 0.0, p.y)
	node.rotation_degrees.y = float(item.get("rot", 0))
	node.scale = Vector3.ONE * float(item.get("scale", 1.0)) * (scale_k if item.asset in ["island", "levistone"] else 1.0)
	node.name = "%s_%d" % [item.asset, get_child_count()]
	add_child(node)

	if LIGHTS.has(item.asset):
		var cfg: Dictionary = LIGHTS[item.asset]
		var light := OmniLight3D.new()
		light.position = cfg.offset
		light.light_color = cfg.color
		light.light_energy = cfg.energy
		light.omni_range = cfg.range
		light.shadow_enabled = false
		node.add_child(light)

	match item.asset:
		"campfire":
			node.add_child(Effects.fire())
			var fl := Effects.Flicker.new()
			fl.light = _first_light(node)
			node.add_child(fl)
		"water":
			_setup_water(node)
		"tree_0", "tree_1", "tree_2", "tree_3":
			var cols: Array = LEAF_COLORS[item.asset].map(func(h): return Color(h))
			node.add_child(Effects.leaves(cols, 1.9))

	var clear := float(item.get("clear", 0.3))
	if clear > 0:
		_occupied.append([p, clear])
		if not item.asset in WALK_THROUGH:
			_solid.append([p, clear])
	_nav_dirty = true
	item_placed.emit(node, item.asset)
	return node


func _first_light(n: Node) -> OmniLight3D:
	for c in n.get_children():
		if c is OmniLight3D:
			return c
	return null


## 물: 재질을 흐르는 물 셰이더로 교체 + 폭포 끝(가장 낮은 점)에 물보라
func _setup_water(node: Node3D) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WATER_META))
	var mat := Effects.water_material(meta)
	var lowest := Vector3(0, INF, 0)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			if m.surface_get_material(s) and m.surface_get_material(s).resource_name == "Water":
				mi.set_surface_override_material(s, mat)
			for v in m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				if v.y < lowest.y:
					lowest = v
	if lowest.y < INF:
		var mist := Effects.mist(Vector3(lowest.x, 0, lowest.z))
		mist.position = lowest
		node.add_child(mist)


## 빈 자리에 풀 등을 무작위로 흩뿌림 (seed 고정 → 매번 같은 결과)
func _scatter(cfg: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	var placed := 0
	var tries := 0
	while placed < int(cfg.count * scale_k * scale_k) and tries < 4000:
		tries += 1
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf_range(pow(cfg.min_r / cfg.max_r, 2), 1.0)) * float(cfg.max_r) * scale_k
		var p := Vector2(cos(ang), sin(ang)) * r
		if _is_blocked(p):
			continue
		var node := _model(cfg.asset)
		node.position = Vector3(p.x, 0, p.y)
		node.rotation.y = rng.randf() * TAU
		node.scale = Vector3.ONE * rng.randf_range(cfg.scale[0], cfg.scale[1])
		add_child(node)
		placed += 1


# ------------------------------------------------------------------ 확장 섬 (증축 · 확장 섬 2개에서 고쳐 씀)
func islet_meta(i: int) -> Dictionary:
	if _islet_meta.is_empty():
		_islet_meta = JSON.parse_string(FileAccess.get_file_as_string(ISLETS_META))
	return _islet_meta[i]


## 확장 섬 i + 밧줄 다리 붙이기 (이미 있으면 무시)
func add_islet(i: int) -> void:
	if i in islets_added:
		return
	islets_added.append(i)
	_nav_dirty = true
	for asset in ["islet_%d" % i, "bridge_%d" % i]:
		var node := _model(asset)
		node.name = asset
		add_child(node)
		item_placed.emit(node, asset)


## 그 위치의 땅 높이: 본섬 0, 확장 섬은 그 섬 높이, 다리 위는 양 끝 높이 사이
func ground_height(p: Vector2) -> float:
	for i in islets_added:
		var m := islet_meta(i)
		if p.distance_to(_v2(m.center)) < float(m.radius) + 0.1:
			return float(m.get("height", 0.0))
	for i in islets_added:
		var m := islet_meta(i)
		var a := _v2(m.bridge[0])
		var c := _v2(m.bridge[1])
		var ab := c - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(a + ab * t) < 0.35 and p.length() > 4.3 * scale_k:
			return float(m.get("height", 0.0)) * t
	return 0.0


## 어느 섬인지: -1 = 본섬, 0·1 = 확장 섬
func region_of(p: Vector2) -> int:
	for i in islets_added:
		var m := islet_meta(i)
		if p.distance_to(_v2(m.center)) < float(m.radius) - 0.2:
			return i
	return -1


# ------------------------------------------------------------------ 길찾기 (직원 이동은 M2 에서 이 위에)
var _nav: AStarGrid2D
var _nav_dirty := true


func _nav_cell(p: Vector2) -> Vector2i:
	return Vector2i(((p - NAV_RECT.position) / NAV_CELL).floor())


func _nav_point(c: Vector2i) -> Vector2:
	return NAV_RECT.position + (Vector2(c) + Vector2(0.5, 0.5)) * NAV_CELL


## 걸을 수 있는 칸 지도 (장애물·섬이 바뀌면 다시 만듦)
func _nav_grid() -> AStarGrid2D:
	if _nav and not _nav_dirty:
		return _nav
	var t0 := Time.get_ticks_usec()
	_nav = AStarGrid2D.new()
	_nav.region = Rect2i(Vector2i.ZERO, Vector2i((NAV_RECT.size / NAV_CELL).ceil()))
	_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	_nav.update()
	for x in _nav.region.size.x:
		for y in _nav.region.size.y:
			var c := Vector2i(x, y)
			if not is_walkable(_nav_point(c)):
				_nav.set_point_solid(c)
	_nav_dirty = false
	if "--profile" in Game.dev_args():
		print("[PROF]   길찾기 지도 %d ms (칸 %d개)" % [(Time.get_ticks_usec() - t0) / 1000, _nav.region.size.x * _nav.region.size.y])
	return _nav


## a → b 걸어갈 경로 (지점 목록, 첫 점 = a 근처). 길이 없으면 빈 배열
func find_path(a: Vector2, b: Vector2) -> Array:
	var g := _nav_grid()
	var ca := _free_cell(g, _nav_cell(a))
	var cb := _free_cell(g, _nav_cell(b))
	if ca.x < 0 or cb.x < 0:
		return []
	var ids := g.get_id_path(ca, cb)
	if ids.is_empty():
		return []
	var out: Array = []
	for k in ids.size():   # 3칸마다 하나 + 마지막 (너무 촘촘하면 걸음이 멈칫거림)
		if k % 3 == 0 or k == ids.size() - 1:
			out.append(_nav_point(ids[k]))
	out[out.size() - 1] = b
	return out


## 걸을 수 있는 칸을 이어진 덩어리로 나눔 → {칸: 덩어리 번호}, 0번 = 앞마당과 이어진 덩어리 (갇힌 틈 찾기)
var _regions := {}
var _regions_for: AStarGrid2D


func nav_regions() -> Dictionary:
	var g := _nav_grid()
	if _regions_for == g:
		return _regions
	var region := {}
	var start := _free_cell(g, _nav_cell(Vector2(0.5, 1.5)))
	var seeds: Array = [start] if start.x >= 0 else []
	for x in g.region.size.x:
		for y in g.region.size.y:
			seeds.append(Vector2i(x, y))
	var next_id := 0
	for s0 in seeds:
		var s: Vector2i = s0
		if region.has(s) or g.is_point_solid(s):
			continue
		var stack: Array = [s]
		region[s] = next_id
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if g.is_in_boundsv(n) and not g.is_point_solid(n) and not region.has(n):
					region[n] = next_id
					stack.append(n)
		next_id += 1
	_regions = region
	_regions_for = g
	return region


## 그 자리가 앞마당과 이어져 있는지 (갇힌 틈이 아닌지)
func is_reachable(p: Vector2) -> bool:
	var g := _nav_grid()
	var c := _free_cell(g, _nav_cell(p))
	if c.x < 0:
		return false
	return nav_regions().get(c, -1) == 0


## 그 칸이 막혀 있으면 가장 가까운 열린 칸 (서 있는 자리가 가장자리일 때)
func _free_cell(g: AStarGrid2D, c: Vector2i) -> Vector2i:
	for r in 4:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if g.is_in_boundsv(n) and not g.is_point_solid(n):
					return n
	return Vector2i(-1, -1)


## 땅 위인지 (본섬 또는 확장 섬). margin 만큼 가장자리에서 떨어져야 함
func is_land(p: Vector2, margin := 0.0) -> bool:
	if p.length() < 4.4 * scale_k - margin:
		return true
	for i in islets_added:
		var m := islet_meta(i)
		if p.distance_to(_v2(m.center)) < float(m.radius) - 0.35 - margin:
			return true
	return false


## 다리 통로: 본섬의 걸을 수 있는 곳(WALK_RADIUS 안) ~ 확장 섬 안쪽까지 이어진 선
func bridge_path(i: int) -> Array:
	var m := islet_meta(i)
	var c := _v2(m.center)
	var d := c.normalized()   # 다리는 본섬 중심 → 확장 섬 중심 방향
	return [d * (walk_radius() - 0.2), c - d * (float(m.radius) - 0.9)]


func _on_bridge(p: Vector2) -> bool:
	for i in islets_added:
		var b: Array = bridge_path(i)
		var a: Vector2 = b[0]
		var c: Vector2 = b[1]
		var ab := c - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if p.distance_to(a + ab * t) < 0.26:
			return true
	return false


## 서 있을 수 있는 위치인지 (본섬·확장 섬·다리 위 + 장애물·연못 밖)
func walk_radius() -> float:
	return WALK_RADIUS * scale_k


## 사무실 가구 · 벽 등록 (office.gd). 사각형은 월드 미터 [x, z]
func add_solid_rect(r: Rect2) -> void:
	_solid_rects.append(r)
	_occupied_rects.append(r.grow(0.1))
	_nav_dirty = true


func add_occupied_rect(r: Rect2) -> void:
	_occupied_rects.append(r)


func add_walk_rect(r: Rect2) -> void:
	_walk_rects.append(r)
	_nav_dirty = true


func is_walkable(p: Vector2) -> bool:
	var on_land := (walk_circle and p.length() <= walk_radius()) or _on_bridge(p)
	if not on_land:
		for r in _walk_rects:
			if r.has_point(p):
				on_land = true
	if not on_land:
		for i in islets_added:
			var m := islet_meta(i)
			if p.distance_to(_v2(m.center)) < float(m.radius) - 0.4:
				on_land = true
	if not on_land:
		return false
	for o in _solid:
		if p.distance_to(o[0]) < o[1]:
			return false
	for r in _solid_rects:
		if r.has_point(p):
			return false
	return true


func _is_blocked(p: Vector2) -> bool:
	for o in _occupied:
		if p.distance_to(o[0]) < o[1]:
			return true
	for r in _occupied_rects:
		if r.has_point(p):
			return true
	return false


func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
