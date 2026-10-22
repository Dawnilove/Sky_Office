extends Node
## 바탕화면용 창 동작: 클릭 통과 영역, 드래그 이동, 창 모드(일반/항상 위/바탕화면 고정)
## (0단계 PoC에서 검증한 방식을 정리한 것)

enum Mode { NORMAL, ALWAYS_ON_TOP, DESKTOP_BOTTOM }
const MODE_NAMES := ["일반", "항상 위", "바탕화면 고정"]

var camera: Camera3D
var target: Node3D          ## 클릭 영역 계산 대상 (섬 전체)
var mode := Mode.NORMAL
## 섬 클릭 처리기 func(화면 좌표) -> bool. true를 돌려주면 클릭을 쓴 것 → 창 드래그 안 함
var click_handler: Callable

var _layer: Node            ## C# WindowLayer
var _dragging := false
var _drag_offset := Vector2i.ZERO
var _hull := PackedVector2Array()
var _static_points := PackedVector2Array()
var _timer := 0.0
var _shape_queued := false  ## 이번 프레임에 윤곽 다시 계산이 이미 예약됨 (여러 번 불려도 한 번만)
var _mesh_verts := {}       ## 메시 → 꼭짓점 (그래픽카드에서 한 번만 읽어 기억 — 풀·돌은 같은 메시를 여러 번 씀)
var mini := false           ## 미니 모드: 창 전체를 그리고(클릭 영역 없음) 클릭은 창 스타일로 통과


func _ready() -> void:
	_layer = load("res://scripts/window/WindowLayer.cs").new()
	add_child(_layer)
	rebuild_static_shape.call_deferred()


## 정적인 물체(섬·집·나무·연기 영역 등)의 화면 윤곽을 미리 계산
## 물체를 옮기면(꾸미기 모드 등) 다시 호출할 것
## 같은 프레임에 여러 번 불려도 프레임 끝에 한 번만 계산 (시작할 때 4번 → 1번)
func rebuild_static_shape() -> void:
	if not _shape_queued:
		_shape_queued = true
		_rebuild_now.call_deferred()


func _rebuild_now() -> void:
	_shape_queued = false
	if camera == null or target == null:
		return
	var t0 := Time.get_ticks_usec()
	_static_points = PackedVector2Array()
	var skip := target.get_node_or_null("Animals")   # 동물은 섬 윤곽 안에 있으므로 제외
	for node in target.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if (skip and skip.is_ancestor_of(gi)) or _is_dynamic(gi):
			continue
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			_static_points.append_array(_project_mesh(gi))
		elif gi is GPUParticles3D and (gi as GPUParticles3D).emitting:   # 파티클(연기 등)은 보이는 범위 상자로 (꺼진 비·눈 제외)
			_static_points.append_array(_project_aabb(gi.global_transform * (gi as GPUParticles3D).visibility_aabb))
	var t1 := Time.get_ticks_usec()
	update_passthrough()
	if "--profile" in Game.dev_args():
		print("[PROF]   섬 윤곽 계산 %d ms (물체 %d개) + 클릭 영역 %d ms" % [(t1 - t0) / 1000, target.find_children("*", "GeometryInstance3D", true, false).size(), (Time.get_ticks_usec() - t1) / 1000])


## 섬(정적 윤곽) + 움직이는 물체(구름·고래) + UI 카드 → 각자 윤곽을 합쳐 하나의 다각형으로
## 떨어진 조각은 2px 다리로 이어 붙임 (Windows는 다각형 하나만 받음)
## 주의: Windows에선 이 다각형 밖은 그려지지도 않음 → 보이는 물체는 모두 포함해야 함
func update_passthrough() -> void:
	if mini:
		if not _hull.is_empty():
			_hull = PackedVector2Array()
			DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
		return
	var shapes: Array[PackedVector2Array] = []
	var island_hull := _hull_of(_static_points)
	if island_hull.size() >= 3:
		var grown := Geometry2D.offset_polygon(island_hull, 22.0)   # 흔들림·둥실 움직임 여유
		shapes.append(grown[0] if grown.size() > 0 else island_hull)
	for n in get_tree().get_nodes_in_group("dynamic_bounds"):
		var pts := PackedVector2Array()
		for mi in (n as Node).find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
			pts.append_array(_project_aabb(mi.global_transform * mi.get_aabb()))
		var h := _hull_of(pts)
		if h.size() >= 3:
			shapes.append(h)
	for n in get_tree().get_nodes_in_group("ui_bounds"):   # UI 카드(HUD·메뉴·패널)
		var c := n as Control
		if c.is_visible_in_tree():
			var xf := c.get_global_transform_with_canvas()   # UI 배율(CanvasLayer)까지 반영한 화면 좌표
			var r := Rect2(Vector2(-8, -8), c.size + Vector2(16, 16))   # 그림자 여유
			shapes.append(PackedVector2Array([xf * r.position, xf * (r.position + Vector2(r.size.x, 0)), xf * r.end,
					xf * (r.position + Vector2(0, r.size.y))]))
	var poly := _merge_all(shapes)
	if "--debug-hull" in Game.dev_args():
		for s in shapes:
			var r := Rect2(s[0], Vector2.ZERO)
			for q in s:
				r = r.expand(q)
			print("[HULL] 조각 꼭짓점 %d 면적 %.0f 범위 %s" % [s.size(), _area(s), r])
		print("[HULL] 결과 꼭짓점 %d 면적 %.0f" % [poly.size(), _area(poly)])
	if poly != _hull:
		_hull = poly
		DisplayServer.window_set_mouse_passthrough(poly)


func _hull_of(points: PackedVector2Array) -> PackedVector2Array:
	var h := Geometry2D.convex_hull(points)
	if h.size() > 1:
		h.remove_at(h.size() - 1)
	return h


## 여러 다각형 → 하나: 겹치면 합치고, 떨어져 있으면 가장 가까운 꼭짓점끼리 가는 다리로 연결
func _merge_all(shapes: Array[PackedVector2Array]) -> PackedVector2Array:
	if shapes.is_empty():
		return PackedVector2Array()
	var result := shapes[0]
	for i in range(1, shapes.size()):
		var other := shapes[i]
		var merged := _outer(Geometry2D.merge_polygons(result, other))
		if merged.size() > 0 and Geometry2D.intersect_polygons(result, other).size() > 0:
			result = merged
			continue
		# 떨어져 있음 → 다리 놓기
		var best := [Vector2.ZERO, Vector2.ZERO]
		var best_d := INF
		for a in result:
			for b in other:
				var d := a.distance_squared_to(b)
				if d < best_d:
					best_d = d
					best = [a, b]
		var dir: Vector2 = (best[1] - best[0]).normalized()
		var side := dir.orthogonal() * 1.5
		var bridge := PackedVector2Array([best[0] - dir * 3 + side, best[1] + dir * 3 + side, best[1] + dir * 3 - side, best[0] - dir * 3 - side])
		var step1 := _outer(Geometry2D.merge_polygons(result, bridge))
		var step2 := _outer(Geometry2D.merge_polygons(step1 if step1.size() > 0 else result, other))
		if step2.size() > 0:
			result = step2
	return result


## merge 결과 중 바깥 테두리(가장 넓은 것)만 사용
func _outer(polys: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := 0.0
	for p in polys:
		if Geometry2D.is_polygon_clockwise(p) and polys.size() > 1:
			continue   # 구멍
		var area := _area(p)
		if area > best_area:
			best_area = area
			best = p
	return best


func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		s += p[i].cross(p[(i + 1) % p.size()])
	return abs(s) * 0.5


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.1 and not get_tree().get_nodes_in_group("dynamic_bounds").is_empty():
		_timer = 0.0
		update_passthrough()


## 섬 윤곽(정적) 계산에서 뺄 물체: 움직이는 물체(dynamic_bounds) + 따로 다루는 물체(no_bounds, 예: 등대 불빛)
func _is_dynamic(n: Node) -> bool:
	for g in ["dynamic_bounds", "no_bounds"]:
		for d in get_tree().get_nodes_in_group(g):
			if d == n or (d as Node).is_ancestor_of(n):
				return true
	return false


func _project_mesh(mi: MeshInstance3D) -> PackedVector2Array:
	var xf := mi.global_transform
	var local := PackedVector2Array()
	if not _mesh_verts.has(mi.mesh):
		var all := PackedVector3Array()
		for s in mi.mesh.get_surface_count():
			all.append_array(mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
		_mesh_verts[mi.mesh] = all
	for v in _mesh_verts[mi.mesh]:
		var w: Vector3 = xf * v
		if not camera.is_position_behind(w):
			local.append(camera.unproject_position(w))
	return Geometry2D.convex_hull(local)   # 물체별 윤곽만 모아 계산량 절약


func _project_aabb(box: AABB) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 8:
		var c := box.get_endpoint(i)
		if not camera.is_position_behind(c):
			out.append(camera.unproject_position(c))
	return out


func get_hull() -> PackedVector2Array:
	return _hull


func set_mode(m: int) -> void:
	mode = m as Mode
	_layer.call("SetBottom", false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, m == Mode.ALWAYS_ON_TOP)
	if m == Mode.DESKTOP_BOTTOM:
		_layer.call("SetBottom", true)


## HUD 손잡이 등에서 창 끌기 시작
func begin_drag() -> void:
	_dragging = true
	_drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()


## 저장된 창 위치 복원 (화면 밖이면 무시)
func restore_position(pos) -> void:
	if typeof(pos) != TYPE_ARRAY or pos.size() != 2:
		return
	var p := Vector2i(int(pos[0]), int(pos[1]))
	var center := p + DisplayServer.window_get_size() / 2
	for i in DisplayServer.get_screen_count():
		var r := Rect2i(DisplayServer.screen_get_position(i), DisplayServer.screen_get_size(i))
		if r.has_point(center):
			DisplayServer.window_set_position(p)
			return


func _input(event: InputEvent) -> void:
	# 드래그 중 이동·놓기 (시작은 _unhandled_input / begin_drag)
	if _dragging:
		if event is InputEventMouseMotion:
			DisplayServer.window_set_position(DisplayServer.mouse_get_position() - _drag_offset)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false
			var wp := DisplayServer.window_get_position()
			Game.settings.window_pos = [wp.x, wp.y]
			Game.save_game()

	# 개발용 단축키
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1: Game.set_setting("window_mode", Mode.NORMAL)
			KEY_F2: Game.set_setting("window_mode", Mode.ALWAYS_ON_TOP)
			KEY_F3: Game.set_setting("window_mode", Mode.DESKTOP_BOTTOM)


func _unhandled_input(event: InputEvent) -> void:
	# 섬 클릭 → 게임 상호작용(작물·동물 등). 창 옮기기는 HUD 손잡이(⠿)로만 (실수로 옮겨지지 않게)
	# 단, UI를 숨긴 상태에선 손잡이가 없으므로 섬을 끌어 옮길 수 있음
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if click_handler.is_valid() and click_handler.call(event.position):
			return
		if not Game.settings.ui_visible:
			begin_drag()
