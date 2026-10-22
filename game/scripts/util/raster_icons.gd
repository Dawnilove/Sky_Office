extends RefCounted
## 3D 공간에 띄울 작은 아이콘 텍스처를 코드로 그림 (말풍선 + 사과 / 달 등)
## 4배 크기로 그린 뒤 줄여서 가장자리를 부드럽게

const SS := 4   ## 슈퍼샘플링 배수

static var _cache := {}


static func get_texture(icon: String, px := 64) -> Texture2D:
	var key := "%s_%d" % [icon, px]
	if not _cache.has(key):
		var n := px * SS
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		match icon:
			"hungry": _hungry(img, n)
			"moon": _moon(img, n)
			"ripe": _ripe(img, n)
			"island": _island(img, n)
			"office": _office(img, n, false)
			"office_turn": _office(img, n, true)
			"letter": _letter(img, n)
			"terminal": _terminal(img, n)
			"milk", "wool", "egg", "request": _bubble(img, n, icon)
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## 원 채우기 (거리 함수)
static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	var x0 := maxi(0, int(c.x - r))
	var x1 := mini(img.get_width() - 1, int(c.x + r))
	var y0 := maxi(0, int(c.y - r))
	var y1 := mini(img.get_height() - 1, int(c.y + r))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if Vector2(x, y).distance_to(c) <= r:
				img.set_pixel(x, y, col)


## 배고픔: 흰 말풍선 안에 빨간 사과
static func _hungry(img: Image, n: int) -> void:
	var c := Vector2(n * 0.5, n * 0.44)
	_disc(img, c, n * 0.4, Color("8a7d70"))
	_disc(img, c, n * 0.36, Color("fffaf0"))
	for i in 12:   # 말풍선 꼬리
		_disc(img, Vector2(n * 0.5, n * 0.82 + i), n * 0.06 - i * 0.6, Color("fffaf0"))
	_disc(img, c + Vector2(-n * 0.07, n * 0.04), n * 0.17, Color("e0484f"))
	_disc(img, c + Vector2(n * 0.07, n * 0.04), n * 0.17, Color("e0484f"))
	_disc(img, c + Vector2(-n * 0.1, -n * 0.03), n * 0.05, Color(1, 1, 1, 0.8))
	_disc(img, c + Vector2(n * 0.06, -n * 0.17), n * 0.06, Color("6fae4a"))


## 잠: 노란 초승달 + 작은 별
static func _moon(img: Image, n: int) -> void:
	var c := Vector2(n * 0.46, n * 0.5)
	_disc(img, c, n * 0.36, Color("f6d36b"))
	_disc(img, c + Vector2(n * 0.17, -n * 0.1), n * 0.3, Color(0, 0, 0, 0))
	_disc(img, Vector2(n * 0.78, n * 0.28), n * 0.05, Color("fff3c4"))
	_disc(img, Vector2(n * 0.7, n * 0.72), n * 0.035, Color("fff3c4"))


## 수확 가능: 반짝이는 별
static func _ripe(img: Image, n: int) -> void:
	var c := Vector2(n * 0.5, n * 0.5)
	for y in n:
		for x in n:
			var d := Vector2(x, y) - c
			var a := atan2(d.y, d.x)
			var r := n * (0.22 + 0.2 * pow(abs(cos(2.0 * a)), 6.0))
			if d.length() <= r:
				img.set_pixel(x, y, Color("ffd65a"))


## 트레이용 떠 있는 섬: 초록 윗면 + 흙 + 회색 바위 뿌리
static func _island(img: Image, n: int) -> void:
	for y in n:
		for x in n:
			var u := (x - n * 0.5) / (n * 0.46)
			var top := n * 0.36
			if y >= top and y <= top + n * 0.1 and abs(u) <= 1.0:
				img.set_pixel(x, y, Color("6fa83e") if y < top + n * 0.06 else Color("8a5a36"))
			elif y > top + n * 0.1:
				var depth := (y - top - n * 0.1) / (n * 0.5)
				if abs(u) <= 1.0 - depth and depth <= 1.0:
					img.set_pixel(x, y, Color("6d6a78") if (x + y) % 9 > 2 else Color("5b5966"))
	_disc(img, Vector2(n * 0.38, n * 0.26), n * 0.12, Color("e3832f"))   # 나무
	_disc(img, Vector2(n * 0.62, n * 0.24), n * 0.1, Color("e5b84a"))


## 둥근 네모 채우기 (모서리 반지름 r)
static func _rrect(img: Image, r: Rect2, rad: float, col: Color) -> void:
	for y in range(maxi(0, int(r.position.y)), mini(img.get_height(), int(r.end.y))):
		for x in range(maxi(0, int(r.position.x)), mini(img.get_width(), int(r.end.x))):
			var q := Vector2(clampf(x, r.position.x + rad, r.end.x - rad), clampf(y, r.position.y + rad, r.end.y - rad))
			if Vector2(x, y).distance_to(q) <= rad:
				img.set_pixel(x, y, col)


## 트레이용 하늘 오피스 (M4 1세션째 사용자 결정): 둥근 하늘 바탕 + 구름 + 남색 4:3 건물 · 하늘색 창 6개
##   turn = 내 차례 15초 → 오른쪽 아래 노랑 점 (진한 테). 노랑은 이 점에만
static func _office(img: Image, n: int, turn: bool) -> void:
	var k := n / 256.0
	var bg := Rect2(8 * k, 8 * k, 240 * k, 240 * k)
	for y in range(int(bg.position.y), int(bg.end.y)):   # 위가 진하고 아래가 연한 하늘
		var t := float(y) / n
		_rrect(img, Rect2(bg.position.x, y, bg.size.x, 1), 0.0, Color8(int(70 + 60 * t), int(150 + 50 * t), int(210 + 25 * t)))
	var mask := Image.create(n, n, false, Image.FORMAT_RGBA8)   # 둥근 모서리 밖은 지움
	_rrect(mask, bg, 60 * k, Color.WHITE)
	for y in n:
		for x in n:
			if mask.get_pixel(x, y).a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var cloud := Color("def0fa")
	_disc(img, Vector2(188, 58) * k, 30 * k, cloud)
	_disc(img, Vector2(150, 66) * k, 22 * k, cloud)
	_disc(img, Vector2(212, 64) * k, 18 * k, cloud)
	_rrect(img, Rect2(44 * k, 104 * k, 168 * k, 108 * k), 0.0, Color("3f4c6b"))   # 벽
	_rrect(img, Rect2(34 * k, 90 * k, 188 * k, 20 * k), 0.0, Color("232a3c"))     # 지붕
	for i in 3:
		for j in 2:
			_rrect(img, Rect2((62 + i * 48) * k, (126 + j * 40) * k, 34 * k, 28 * k), 4 * k, Color("9fdcf0"))
	_rrect(img, Rect2(116 * k, 174 * k, 24 * k, 38 * k), 0.0, Color("232a3c"))     # 문
	if turn:
		_disc(img, Vector2(n, n) * 0.8, n * 0.17 * 1.25, Color("5a4000"))
		_disc(img, Vector2(n, n) * 0.8, n * 0.17, Color("ffd21f"))


## 모니터 '실행' 화면 (M4 5세션째 ②): 검은 바탕 + 초록 글줄 (길이 제각각)
static func _terminal(img: Image, n: int) -> void:
	img.fill(Color("14201a"))
	var lens := [0.55, 0.8, 0.35, 0.7, 0.45, 0.62]
	for j in lens.size():
		var y := n * (0.08 + j * 0.15)
		_rrect(img, Rect2(n * 0.08, y, n * 0.84 * float(lens[j]), n * 0.07), 0.0, Color("6fe08f") if j != 0 else Color("b6f5c8"))


## 우체통 선물: 흰 봉투 + 빨간 봉인
static func _letter(img: Image, n: int) -> void:
	var r := Rect2(n * 0.12, n * 0.25, n * 0.76, n * 0.52)
	for y in n:
		for x in n:
			var p := Vector2(x, y)
			if r.grow(n * 0.03).has_point(p):
				img.set_pixel(x, y, Color("8a7d70"))
			if r.has_point(p):
				img.set_pixel(x, y, Color("fffaf0"))
				var v: float = abs((x - n * 0.5) * 0.68) - (y - n * 0.25)   # 봉투 덮개 V자 선
				if abs(v) < n * 0.025:
					img.set_pixel(x, y, Color("c9bba8"))
	_disc(img, Vector2(n * 0.5, n * 0.52), n * 0.09, Color("e0484f"))


## 흰 말풍선 안에 생산물/느낌표
static func _bubble(img: Image, n: int, what: String) -> void:
	var c := Vector2(n * 0.5, n * 0.44)
	_disc(img, c, n * 0.4, Color("8a7d70"))
	_disc(img, c, n * 0.36, Color("fffaf0"))
	for i in 12:
		_disc(img, Vector2(n * 0.5, n * 0.82 + i), n * 0.06 - i * 0.6, Color("fffaf0"))
	match what:
		"milk":   # 우유병: 흰 몸통 + 파란 뚜껑
			for y in range(int(n * 0.3), int(n * 0.66)):
				for x in range(int(n * 0.4), int(n * 0.6)):
					img.set_pixel(x, y, Color("e9eef5") if y > n * 0.38 else Color("4b8fd6"))
			_disc(img, Vector2(n * 0.5, n * 0.58), n * 0.1, Color("e9eef5"))
		"wool":   # 양털 뭉치
			for d in [Vector2(-0.1, 0.03), Vector2(0.1, 0.03), Vector2(0, -0.07), Vector2(0, 0.1)]:
				_disc(img, c + d * n, n * 0.12, Color("e8e2d6"))
			_disc(img, c + Vector2(-0.03, -0.02) * n, n * 0.05, Color("fffdf8"))
		"egg":
			for y in n:
				for x in n:
					var q := Vector2(x, y) - (c + Vector2(0, 0.02) * n)
					if (q.x / (n * 0.13)) ** 2 + (q.y / (n * 0.17)) ** 2 <= 1.0:
						img.set_pixel(x, y, Color("f3dfb8"))
		"request":   # 느낌표
			for y in range(int(n * 0.22), int(n * 0.5)):
				for x in range(int(n * 0.45), int(n * 0.55)):
					img.set_pixel(x, y, Color("e0484f"))
			_disc(img, Vector2(n * 0.5, n * 0.6), n * 0.06, Color("e0484f"))


## ------------------------------------------------------------------ 도구 아이콘 7장 (M4 5세션째, 5-1 '방금 쓴 도구' — 이름판 점 옆, 최소 1.5초)
## 종류 = office_routine.TOOL_KIND: edit 연필 · read 책 · run >_ · web 지구 · agent 두 사람 · plan 체크리스트 · other 톱니
## 그림 = 거리 함수 (칸 0~1, 음수 = 안). style: A 흰 원 + 남색 그림 · B 하늘색 원 + 흰 그림 · C 원 없이 흰 그림 + 남색 테
const TOOL_KINDS := ["edit", "read", "run", "web", "agent", "plan", "other"]
const C_NAVY := Color("3f4c6b")


static func tool_texture(kind: String, style := "A", px := 64) -> Texture2D:
	var key := "tool_%s_%s_%d" % [kind, style, px]
	if not _cache.has(key):
		var n := px * SS
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var edge := 1.5 / n   # 부드러운 가장자리 (줄이기 전 1.5px)
		for y in n:
			for x in n:
				var p := Vector2(x + 0.5, y + 0.5) / n
				var g := _tool_sdf(kind, p)
				var col := Color(0, 0, 0, 0)
				match style:
					"A", "B":
						var disc := p.distance_to(Vector2(0.5, 0.5))
						var bg := Color.WHITE if style == "A" else Color("4aa8e0")
						var fg := C_NAVY if style == "A" else Color.WHITE
						col = _over(col, C_NAVY.darkened(0.25), 0.5 - disc, edge)
						col = _over(col, bg, 0.455 - disc, edge)
						col = _over(col, fg, -g, edge)
					_:
						col = _over(col, C_NAVY, 0.055 - g, edge)
						col = _over(col, Color.WHITE, -g, edge)
				img.set_pixel(x, y, col)
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## 위에 덮기: d > 0 이면 안 (가장자리는 edge 폭으로 섞음)
static func _over(under: Color, top: Color, d: float, edge: float) -> Color:
	var a := clampf(d / edge + 0.5, 0.0, 1.0)
	if a <= 0.0:
		return under
	var c := top
	c.a = a + under.a * (1.0 - a)
	if c.a > 0.0:
		var t := a / c.a
		c.r = lerpf(under.r, top.r, t)
		c.g = lerpf(under.g, top.g, t)
		c.b = lerpf(under.b, top.b, t)
	return c


static func _sd_seg(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length() - r


static func _sd_box(p: Vector2, c: Vector2, half: Vector2, r := 0.0) -> float:
	var q := (p - c).abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


static func _tool_sdf(kind: String, p: Vector2) -> float:
	match kind:
		"edit":   # 연필: 몸통 (비스듬) + 뾰족한 끝
			var d := _sd_seg(p, Vector2(0.4, 0.6), Vector2(0.7, 0.3), 0.085)
			var tip := maxf(_sd_seg(p, Vector2(0.27, 0.73), Vector2(0.4, 0.6), 0.085), (p - Vector2(0.27, 0.73)).dot(Vector2(-0.7071, 0.7071)) - 0.0)
			tip = maxf(_sd_seg(p, Vector2(0.25, 0.75), Vector2(0.42, 0.58), 0.085 * ((p - Vector2(0.25, 0.75)).length() / 0.24)), -1.0)
			return minf(d, tip)
		"read":   # 펼친 책: 두 쪽 + 가운데 틈
			var l := _sd_box(p, Vector2(0.335, 0.52), Vector2(0.135, 0.19), 0.03)
			var r := _sd_box(p, Vector2(0.665, 0.52), Vector2(0.135, 0.19), 0.03)
			var d := minf(l, r)
			for yy in [0.44, 0.54, 0.64]:   # 글줄 (파임)
				d = maxf(d, -minf(_sd_seg(p, Vector2(0.26, yy), Vector2(0.41, yy), 0.018), _sd_seg(p, Vector2(0.59, yy), Vector2(0.74, yy), 0.018)))
			return d
		"run":   # >_
			var c := minf(_sd_seg(p, Vector2(0.26, 0.33), Vector2(0.44, 0.5), 0.06), _sd_seg(p, Vector2(0.44, 0.5), Vector2(0.26, 0.67), 0.06))
			return minf(c, _sd_seg(p, Vector2(0.52, 0.67), Vector2(0.74, 0.67), 0.06))
		"web":   # 지구: 테 + 세로 타원 + 가로줄
			var q := p - Vector2(0.5, 0.5)
			var ring := absf(q.length() - 0.25) - 0.045
			var ell := absf(Vector2(q.x / 0.42, q.y).length() - 0.25) * 0.42 - 0.035
			var eq := _sd_seg(p, Vector2(0.27, 0.5), Vector2(0.73, 0.5), 0.035)
			return minf(ring, maxf(minf(ell, eq), q.length() - 0.25))
		"agent":   # 두 사람 (뒤 작은 사람 + 앞 사람)
			var back := minf((p - Vector2(0.36, 0.33)).length() - 0.09, _sd_box(p, Vector2(0.36, 0.6), Vector2(0.15, 0.14), 0.1))
			var front := minf((p - Vector2(0.6, 0.4)).length() - 0.11, _sd_box(p, Vector2(0.6, 0.71), Vector2(0.18, 0.15), 0.12))
			front = maxf(front, p.y - 0.78)
			back = maxf(back, p.y - 0.7)
			var gap := minf((p - Vector2(0.6, 0.4)).length() - 0.16, _sd_box(p, Vector2(0.6, 0.71), Vector2(0.23, 0.2), 0.16))
			return minf(front, maxf(back, -gap))
		"plan":   # 체크리스트: 위 두 줄 체크 + 아래 빈 칸
			var d := 1.0
			for i in 3:
				var y := 0.31 + i * 0.19
				d = minf(d, _sd_seg(p, Vector2(0.47, y), Vector2(0.75, y), 0.045))
				if i < 2:
					d = minf(d, minf(_sd_seg(p, Vector2(0.24, y), Vector2(0.29, y + 0.05), 0.04), _sd_seg(p, Vector2(0.29, y + 0.05), Vector2(0.38, y - 0.06), 0.04)))
				else:
					d = minf(d, absf(_sd_box(p, Vector2(0.31, y), Vector2(0.06, 0.06), 0.02)) - 0.025)
			return d
		_:   # 톱니
			var q := p - Vector2(0.5, 0.5)
			var a := atan2(q.y, q.x)
			var teeth := 0.24 + 0.06 * clampf(cos(a * 8.0) * 3.0, -1.0, 1.0)
			return maxf(q.length() - teeth, 0.085 - q.length())
