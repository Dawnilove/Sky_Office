extends RefCounted
## 구역 배치 (PLAN v2.3 3장 · 9-2): data/zones.json + 섬 지름 → 실제 위치
## 하늘에 뜬 사무실 하나 (뒷벽 고정, 폭 · 앞쪽은 반지름 비율) 안에 작업실 · 창구 · 휴게 + 왼쪽 벽에 붙은 승강장 부두 (v2.4)
## v2.6: 가로 4:3 · 앞뒤 2단 — 뒤 = 작업실 전체 폭, 앞줄 = 휴게 | 창구 (경계 x 고정, 휴게는 왼벽 · 창구는 오른벽까지)
## 신호 3개: 호출 보드 · 깃대 = 고정 좌표, 창구 = 오른벽 기준 고정 (v2.6). 나머지 = 비율 · 벽 기준 슬롯 → 증축 때 데이터만 바꿈
## 좌표는 모두 '칸' (1칸 = unit_m 미터). 월드 미터가 필요하면 m() · m3()

const PATH := "res://data/zones.json"

var data: Dictionary
var diameter := 10
var R := 5.0          ## 반지름 (칸)
var unit_m := 0.88
var desk_cols := 2


func _init(d := 10, path := PATH) -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	diameter = clampi(d, int(data.diameter_min), int(data.diameter_max))
	R = diameter / 2.0
	unit_m = float(data.unit_m)
	desk_cols = diameter + int(data.desk_cols_minus_diameter)   # 10 → 2열 (책상 4) … 14 → 6열 (책상 12)


## 칸 → 월드 미터 (Vector2 = [x, z])
func m(p: Vector2) -> Vector2:
	return p * unit_m


func m3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x * unit_m, y * unit_m, p.y * unit_m)


# ------------------------------------------------------------------ 신호 (고정 좌표)
func fixed(name: String) -> Dictionary:
	return data.fixed[name]


## 호출 보드 · 깃대 = 좌표 고정, 창구 = 오른벽 기준 고정 (edge: 증축하면 벽과 함께 옮김, v2.6)
func signal_pos(name: String) -> Vector2:
	var f: Dictionary = data.fixed[name]
	return _edge(f.edge, _v2(f.pos)) if f.has("edge") else _v2(f.pos)


# ------------------------------------------------------------------ 건물 (뒷벽 고정, 폭 · 앞쪽은 비율)
func building_rect() -> Rect2:
	var b: Dictionary = data.building
	var hw := float(b.half_w_ratio) * R
	var back := float(b.back_z)
	return Rect2(-hw, back, hw * 2.0, float(b.front_ratio) * R - back)


# ------------------------------------------------------------------ 작업실 (2인 마주보기 책상, 열만 늘어남)
## 열 k 의 x: 팀 책상 섬 (pod_cols 열 = 마주보기 4자리) 단위로 가운데 → 오른쪽 → 왼쪽 … 붙이고, 섬 사이는 통로
## 증축해도 기존 책상이 안 움직임 (1.1 의 3열째는 오른쪽 섬의 첫 열)
func col_x(k: int) -> float:
	var w: Dictionary = data.workroom
	var gap := float(w.col_gap)
	var n := int(w.pod_cols)
	var pod_w := gap * n
	var p := k / n
	var pod_c := 0.0 if p == 0 else (1.0 if p % 2 == 1 else -1.0) * ceilf(p / 2.0) * (pod_w + float(w.pod_aisle))
	return pod_c + (k % n - (n - 1) / 2.0) * gap


func room_rect() -> Rect2:
	var b := building_rect()
	return Rect2(b.position.x, b.position.y, b.size.x, float(data.workroom.front_z) - b.position.y)


## 책상 목록: 열 순서대로 (앞줄 → 뒷줄). {id, pos (책상 중심), seat (앉는 자리), rot (앉아서 보는 쪽), row, col}
## 뒷줄 (row 0) 은 카메라를 보고 앉음 (얼굴), 앞줄 (row 1) 은 뒤를 보고 앉음 (모니터 화면이 카메라 쪽)
## id 순서 = 빈 책상 배정 순서 (4-1). 증축해도 기존 id 의 자리가 그대로
func desks() -> Array:
	var rows: Array = data.workroom.rows
	var out: Array = []
	for c in desk_cols:
		for r in [1, 0]:
			var row: Dictionary = rows[r]
			var x := col_x(c)
			out.append({"id": out.size(), "pos": Vector2(x, float(row.desk_z)), "seat": Vector2(x, float(row.seat_z)),
					"rot": float(row.rot), "row": r, "col": c})
	return out


## 작업실 가구 자리 (건물 왼쪽 · 오른쪽 벽 기준)
func room_slot(name: String) -> Dictionary:
	var s: Dictionary = data.workroom.slots[name]
	return {"pos": _edge(s.edge, _v2(s.pos)), "size": _v2(s.size)}


# ------------------------------------------------------------------ 구역 사각형
func zone_names() -> Array:
	return ["workroom", "counter", "rest", "pier"]


func zone_rect(name: String) -> Rect2:
	if name == "workroom":
		return room_rect()
	if name == "building":
		return building_rect()
	var z: Dictionary = data.zones[name]
	if z.has("fixed_rect"):
		var a: Array = z.fixed_rect
		return Rect2(a[0], a[1], a[2], a[3])
	if z.has("ratio_rect"):
		var b: Array = z.ratio_rect
		return Rect2(b[0] * R, b[1] * R, b[2] * R, b[3] * R)
	if z.has("wall_rect"):   # [x0, z0, x1, z1] — "left" · "right" · "front" = 그 벽까지 (v2.6 앞줄 휴게 | 창구)
		var w: Array = z.wall_rect
		var b := building_rect()
		var v := func(a, wall: String, edge: float) -> float: return edge if str(a) == wall else float(a)
		var x0: float = v.call(w[0], "left", b.position.x)
		var x1: float = v.call(w[2], "right", b.end.x)
		var z1: float = v.call(w[3], "front", b.end.y)
		return Rect2(x0, float(w[1]), x1 - x0, z1 - float(w[1]))
	if z.has("edge"):   # 건물 벽에 붙은 부두 (왼쪽 벽 바깥)
		var size := _v2(z.size)
		var b := building_rect()
		var x := b.position.x - size.x if z.edge == "left" else b.end.x   # 폭은 끝이 벽과 딱 맞는 값으로 (1.75 ○ · 1.8 ✗ = float32 오차로 벽 안쪽 겹침)
		return Rect2(x, float(z.z) - size.y / 2.0, size.x, size.y)
	return Rect2()


# ------------------------------------------------------------------ 슬롯
## 슬롯 위치 목록 [{pos, rot, size}]. 위치 항목에 세 번째 값이 있으면 그 자리만의 rot
func slots(name: String) -> Array:
	var s: Dictionary = data.slots[name]
	var rot := float(s.get("rot", 0))
	var size := _v2(s.get("size", [0, 0]))
	var out: Array = []
	var pts: Array = []
	if s.has("fixed"):
		for p in s.fixed:
			pts.append([_v2(p), p])
	elif s.has("edge"):
		for p in s.pos:
			pts.append([_edge(s.edge, _v2(p)), p])
	elif s.has("zone"):
		var rect := zone_rect(s.zone)
		for p in s.rel:
			pts.append([rect.position + rect.size * _v2(p), p])
	elif s.has("ring"):
		for p in s.ring:
			pts.append([_dir(float(p[0])) * R * float(p[1]), [0, 0]])
	for e in pts:
		var raw: Array = e[1]
		out.append({"pos": e[0], "rot": float(raw[2]) if raw.size() > 2 else rot, "size": size})
	return out


func slot(name: String, i := 0) -> Vector2:
	return slots(name)[i].pos


func _edge(edge: String, p: Vector2) -> Vector2:
	var b := building_rect()
	if edge == "center":   # 건물 가운데 기준 (x 그대로)
		return p
	return Vector2(p.x + (b.position.x if edge == "left" else b.end.x), p.y)


func _dir(deg: float) -> Vector2:
	return Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg)))


func _v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
