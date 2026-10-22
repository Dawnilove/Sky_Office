extends RefCounted
## UI 아이콘을 벡터 도형으로 직접 그림 (이미지 파일 없이, 어떤 크기에서도 선명)
## 사용: Icons.draw(캔버스아이템, "coin", 중심, 반지름)
## tint: 선으로 그리는 아이콘(회전·체크·화살표 등)의 색 (투명이면 기본 진갈색)

const DARK := Color("4a3f35")


static func draw(ci: CanvasItem, icon: String, c: Vector2, r: float, tint := Color(0, 0, 0, 0)) -> void:
	var line: Color = tint if tint.a > 0.0 else DARK
	match icon:
		"rotate": _rotate(ci, c, r, line)
		"box": _box(ci, c, r)
		"check": _check(ci, c, r, line)
		"place": _place(ci, c, r, line)
		"chevron_down": _chevron(ci, c, r, line, 1.0)
		"chevron_up": _chevron(ci, c, r, line, -1.0)
		"coin": _coin(ci, c, r)
		"gem": _gem(ci, c, r)
		"heart": _heart(ci, c, r, Color("e0484f"))
		"heart_empty": _heart(ci, c, r, Color("d6cdbf"))
		"clock": _clock(ci, c, r)
		"pinwheel": _pinwheel(ci, c, r)
		"sun": _sun(ci, c, r)
		"music": _music(ci, c, r)
		"bowl": _bowl(ci, c, r)
		"shop": _shop(ci, c, r)
		"gear": _gear(ci, c, r)
		"tray": _tray(ci, c, r)
		"power": _power(ci, c, r)
		"handle": _handle(ci, c, r)
		"seed": _seed(ci, c, r)
		"close": _close(ci, c, r)
		"carrot": _carrot(ci, c, r)
		"pumpkin": _pumpkin(ci, c, r)
		"wheat": _wheat(ci, c, r)
		"food": _bowl(ci, c, r)


static func _circle_poly(c: Vector2, r: float, n := 24, a0 := 0.0, a1 := TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color("d99a2b"))
	ci.draw_circle(c + Vector2(0, -r * 0.06), r * 0.86, Color("f2c14e"))
	ci.draw_circle(c + Vector2(0, -r * 0.06), r * 0.62, Color("e3a934"))
	# 잎사귀 문양
	var leaf := PackedVector2Array([c + Vector2(-r * 0.32, r * 0.25), c + Vector2(-r * 0.05, -r * 0.35),
			c + Vector2(r * 0.32, -r * 0.3), c + Vector2(r * 0.05, r * 0.3)])
	ci.draw_colored_polygon(leaf, Color("f7d57a"))
	ci.draw_arc(c + Vector2(-r * 0.15, -r * 0.2), r * 0.55, deg_to_rad(-35), deg_to_rad(10), 6, Color(1, 1, 1, 0.7), r * 0.08)


static func _gem(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color("6f53b8"))
	ci.draw_circle(c, r * 0.84, Color("9a7be0"))
	var d := PackedVector2Array([c + Vector2(0, -r * 0.55), c + Vector2(r * 0.45, 0), c + Vector2(0, r * 0.55), c + Vector2(-r * 0.45, 0)])
	ci.draw_colored_polygon(d, Color("d9cbff"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.55), c + Vector2(r * 0.45, 0), c]), Color("f2edff"))


static func _heart(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y + 1.5) * (r / 17.0))
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c + Vector2(-r * 0.42, -r * 0.3), r * 0.16, Color(1, 1, 1, 0.55))


static func _clock(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color("3b5b8c"))
	ci.draw_colored_polygon(_circle_poly(c, r * 0.86, 20, -PI / 2, PI / 2), Color("f2c14e"))      # 낮(오른쪽)
	ci.draw_colored_polygon(_circle_poly(c, r * 0.86, 20, PI / 2, PI * 1.5), Color("2e4a75"))     # 밤(왼쪽)
	ci.draw_circle(c + Vector2(-r * 0.42, -r * 0.2), r * 0.06, Color("fff6c8"))
	ci.draw_circle(c + Vector2(-r * 0.3, r * 0.35), r * 0.05, Color("fff6c8"))
	ci.draw_line(c, c + Vector2(0, -r * 0.62), Color.WHITE, r * 0.14, true)
	ci.draw_line(c, c + Vector2(r * 0.42, r * 0.18), Color.WHITE, r * 0.14, true)
	ci.draw_circle(c, r * 0.12, Color.WHITE)


static func _pinwheel(ci: CanvasItem, c: Vector2, r: float) -> void:
	var cols := [Color("e9584f"), Color("f2c14e"), Color("4b8fd6"), Color("6cbf5b")]
	for k in 4:
		var a := PI / 2 * k - PI / 4
		var dir := Vector2(cos(a), sin(a))
		var side := dir.orthogonal()
		ci.draw_colored_polygon(PackedVector2Array([c, c + dir * r, c + (dir + side) * r * 0.7]), cols[k])
	ci.draw_circle(c, r * 0.14, Color.WHITE)


static func _sun(ci: CanvasItem, c: Vector2, r: float) -> void:
	for k in 8:
		var a := TAU * k / 8.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c + d * r * 0.62, c + d * r * 0.98, Color("f0a52b"), r * 0.18, true)
	ci.draw_circle(c, r * 0.52, Color("f6b93b"))
	ci.draw_circle(c + Vector2(-r * 0.15, -r * 0.15), r * 0.18, Color(1, 1, 1, 0.45))


static func _music(ci: CanvasItem, c: Vector2, r: float) -> void:
	var col := Color("5f8f3e")
	var h1 := c + Vector2(-r * 0.45, r * 0.5)
	var h2 := c + Vector2(r * 0.45, r * 0.32)
	for h in [h1, h2]:
		ci.draw_set_transform(h, -0.35, Vector2(1.3, 0.95))
		ci.draw_circle(Vector2.ZERO, r * 0.26, col)
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	ci.draw_line(h1 + Vector2(r * 0.28, 0), h1 + Vector2(r * 0.28, -r * 1.05), col, r * 0.13)
	ci.draw_line(h2 + Vector2(r * 0.28, 0), h2 + Vector2(r * 0.28, -r * 1.05), col, r * 0.13)
	ci.draw_colored_polygon(PackedVector2Array([h1 + Vector2(r * 0.22, -r * 1.05), h2 + Vector2(r * 0.34, -r * 1.12),
			h2 + Vector2(r * 0.34, -r * 0.82), h1 + Vector2(r * 0.22, -r * 0.75)]), col)


static func _bowl(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.05), r * 0.32, Color("e8913a"))
	ci.draw_circle(c + Vector2(r * 0.25, -r * 0.1), r * 0.3, Color("6fae4a"))
	ci.draw_circle(c + Vector2(0, -r * 0.25), r * 0.28, Color("f2c14e"))
	ci.draw_colored_polygon(_circle_poly(c + Vector2(0, -r * 0.05), r * 0.92, 16, 0, PI), Color("b8653a"))
	ci.draw_line(c + Vector2(-r * 0.92, -r * 0.05), c + Vector2(r * 0.92, -r * 0.05), Color("8c4a2a"), r * 0.16)
	ci.draw_arc(c + Vector2(0, -r * 0.05), r * 0.62, 0.4, PI - 0.4, 10, Color("d98a5a"), r * 0.1)


static func _shop(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.1), Vector2(r * 1.5, r * 0.95)), Color("d9a066"))
	ci.draw_rect(Rect2(c + Vector2(-r * 0.25, r * 0.25), Vector2(r * 0.5, r * 0.6)), Color("8c5a36"))
	var stripes := 5
	var w := r * 1.9 / stripes
	for i in stripes:
		var x0 := c.x - r * 0.95 + i * w
		var col := Color("e9584f") if i % 2 == 0 else Color("fbf3e6")
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, c.y - r * 0.75), Vector2(x0 + w, c.y - r * 0.75),
				Vector2(x0 + w, c.y - r * 0.15), Vector2(x0, c.y - r * 0.15)]), col)
		ci.draw_circle(Vector2(x0 + w / 2, c.y - r * 0.15), w / 2, col)
	ci.draw_rect(Rect2(c + Vector2(-r * 1.0, -r * 0.92), Vector2(r * 2.0, r * 0.2)), Color("8c5a36"))


static func _gear(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var teeth := 8
	for i in teeth * 4:
		var a := TAU * i / (teeth * 4.0)
		var rr := r if (i % 4) in [0, 1] else r * 0.74
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, Color("7d8b6a"))
	ci.draw_circle(c, r * 0.58, Color("93a37e"))
	ci.draw_circle(c, r * 0.26, Color("f4efe6"))


## 결재함: 나무 서류함 + 흰 서류 (M5 3세션째)
static func _tray(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-r * 0.62, -r * 0.82), Vector2(r * 1.24, r * 1.2)), Color("fbf8f2"))
	for k in 3:
		ci.draw_line(c + Vector2(-r * 0.4, -r * (0.55 - k * 0.24)), c + Vector2(r * 0.4, -r * (0.55 - k * 0.24)), Color("b5aca0"), r * 0.1)
	ci.draw_rect(Rect2(c + Vector2(-r * 0.9, r * 0.12), Vector2(r * 1.8, r * 0.62)), Color("b97f45"))
	ci.draw_rect(Rect2(c + Vector2(-r * 0.9, r * 0.12), Vector2(r * 1.8, r * 0.14)), Color("8c5a36"))


static func _power(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color("e0484f"))
	ci.draw_arc(c, r * 0.52, deg_to_rad(-55), deg_to_rad(235), 20, Color.WHITE, r * 0.16, true)
	ci.draw_line(c + Vector2(0, -r * 0.72), c + Vector2(0, -r * 0.1), Color.WHITE, r * 0.16, true)


static func _handle(ci: CanvasItem, c: Vector2, r: float) -> void:
	for x in [-1, 1]:
		for y in [-1, 0, 1]:
			ci.draw_circle(c + Vector2(x * r * 0.28, y * r * 0.5), r * 0.14, Color("9a9088"))


static func _seed(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_colored_polygon(_circle_poly(c + Vector2(0, r * 0.2), r * 0.7, 16, 0, PI), Color("8c5a36"))
	ci.draw_line(c + Vector2(0, r * 0.2), c + Vector2(0, -r * 0.5), Color("5f8f3e"), r * 0.14)
	ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.5), r * 0.25, Color("6fae4a"))
	ci.draw_circle(c + Vector2(r * 0.25, -r * 0.6), r * 0.25, Color("8cc152"))


## 회전: 열린 원호 + 화살촉
static func _rotate(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var rr := r * 0.68
	var a0 := -PI * 0.3
	var a1 := PI * 1.25
	ci.draw_arc(c, rr, a0, a1, 24, col, r * 0.22, true)
	var tip := c + Vector2(cos(a0), sin(a0)) * rr
	var t := Vector2(-sin(a0), cos(a0))   # 원호 진행 방향의 반대(시작점 쪽)
	var n := Vector2(cos(a0), sin(a0))
	ci.draw_colored_polygon(PackedVector2Array([tip - t * r * 0.45, tip + n * r * 0.38 + t * r * 0.1,
			tip - n * r * 0.38 + t * r * 0.1]), col)


## 창고 상자: 나무 상자 + 뚜껑 + 손잡이 홈
static func _box(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.35), Vector2(r * 1.7, r * 1.15)), Color("d9a066"))
	ci.draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.62), Vector2(r * 1.9, r * 0.36)), Color("b97f45"))
	ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.05), Vector2(r * 0.6, r * 0.18)), Color("8c5a36"))


static func _check(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, 0), c + Vector2(-r * 0.15, r * 0.45), c + Vector2(r * 0.65, -r * 0.45)]),
			col, r * 0.26, true)


## 놓기: 아래 화살표 + 땅 선
static func _place(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_line(c + Vector2(0, -r * 0.75), c + Vector2(0, r * 0.25), col, r * 0.22, true)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.1), c + Vector2(0, r * 0.3), c + Vector2(r * 0.4, -r * 0.1)]),
			col, r * 0.22, true)
	ci.draw_line(c + Vector2(-r * 0.7, r * 0.72), c + Vector2(r * 0.7, r * 0.72), col, r * 0.2, true)


static func _chevron(ci: CanvasItem, c: Vector2, r: float, col: Color, dir: float) -> void:
	ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.35 * dir), c + Vector2(0, r * 0.4 * dir),
			c + Vector2(r * 0.8, -r * 0.35 * dir)]), col, r * 0.36, true)


static func _close(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_line(c + Vector2(-r, -r) * 0.6, c + Vector2(r, r) * 0.6, DARK, r * 0.22, true)
	ci.draw_line(c + Vector2(r, -r) * 0.6, c + Vector2(-r, r) * 0.6, DARK, r * 0.22, true)


static func _carrot(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, -r * 0.35), c + Vector2(r * 0.35, -r * 0.35),
			c + Vector2(0, r * 0.95)]), Color("ec8a2f"))
	for a in [-0.5, 0.0, 0.5]:
		ci.draw_line(c + Vector2(0, -r * 0.35), c + Vector2(sin(a) * r * 0.5, -r * 0.95), Color("5f9e3a"), r * 0.16, true)


static func _pumpkin(ci: CanvasItem, c: Vector2, r: float) -> void:
	for dx in [-0.35, 0.35, 0.0]:
		ci.draw_set_transform(c + Vector2(dx * r, r * 0.1), 0, Vector2(0.75, 1))
		ci.draw_circle(Vector2.ZERO, r * 0.6, Color("e3832f") if dx != 0.0 else Color("f09a3e"))
		ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	ci.draw_line(c + Vector2(0, -r * 0.45), c + Vector2(r * 0.15, -r * 0.8), Color("6b4a2f"), r * 0.18)


static func _wheat(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_line(c + Vector2(0, r * 0.9), c + Vector2(0, -r * 0.9), Color("b88a3a"), r * 0.1)
	for i in 4:
		var y := -r * 0.75 + i * r * 0.33
		for s in [-1, 1]:
			ci.draw_set_transform(c + Vector2(s * r * 0.18, y), s * 0.6, Vector2(0.55, 1))
			ci.draw_circle(Vector2.ZERO, r * 0.2, Color("e5b84a"))
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
