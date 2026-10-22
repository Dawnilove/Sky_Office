extends Node
## 미니 모드: 섬이 다른 창(브라우저 등)에 절반 이상 가려진 채 2.5초가 지나면
##   → 섬이 있던 모니터 오른쪽 아래에 아주 작은 섬으로 (항상 위 · 클릭 통과 · 반투명 · 구경만)
## 원래 자리의 가림이 풀린 채 2.5초가 지나면 원래 섬으로 돌아옴. 트레이 아이콘 왼쪽 클릭으로 바로 꺼낼 수도 있음
## 내 차례 15초 (창구에서 부름) 직원이 있으면 반투명 → 선명 (100%), 처리되면 설정 투명도로 (M4 1세션째 사용자 결정)
##   큰 '!' 는 M3 '16px 아래로 안 작아짐' 규칙으로 미니에서도 이미 큼 (실측 약 30px) → 더 키우지 않음
## 일반 · 바탕화면 고정 모드에서만 (항상 위 모드는 가려질 일이 없음). 전체 화면 앱일 땐 기존처럼 숨김이 우선

const DELAY := 2.5          ## 가려짐/풀림이 이만큼 이어져야 바뀜 (창 전환·잠깐 끌기에 깜빡이지 않게)
const THRESHOLD := 0.5      ## 섬 윤곽의 이 비율 이상이 덮이면 "가려짐"
const MINI_K := 0.3375      ## 미니 섬 배율 (기본 창 1080px → 약 365px, M4 5세션째 사용자 +25% → 다시 ×1.5)
const FADE := 0.25
const CHECK := 0.5
const MARGIN := Vector2i(12, 6)
const OfficeRoutine := preload("res://scripts/world/office_routine.gd")

var main: Node
var window_ctl: Node
var ui: CanvasLayer
var layer: Node              ## C# WindowLayer

var active := false
var _busy := false
var _timer := 0.0
var _since := 0.0
var _suppress := false       ## 사용자가 꺼낸 뒤 → 한 번 가림이 풀릴 때까지 다시 들어가지 않음
var _samples := PackedVector2Array()   ## 원래 섬 자리 (화면 좌표) 표본 점
var _orig_pos := Vector2i.ZERO
var _mini_size := Vector2i.ZERO
var _above := PackedInt64Array()   ## 미니 모드 동안 "원래 섬 위에 있는 창": 들어갈 때 위에 있던 창 + 그 뒤 앞으로 나온 창
var _opacity := 1.0
var _op_tw: Tween            ## 부르기에 따른 투명도 바꿈 (들어가기 · 나가기 페이드가 시작되면 멈춤)


func _ready() -> void:
	Game.settings_changed.connect(func() -> void:
		if active and not _busy:
			_set_opacity(_want_opacity()))
	for a in Game.dev_args():   # 개발용: `--mini-now` 2초 뒤 바로 미니 모드 (`--mini-exit=8` 8초 뒤 복귀)
		if a == "--mini-now":
			get_tree().create_timer(2.0).timeout.connect(func() -> void: enter())
		elif a.begins_with("--mini-exit="):
			get_tree().create_timer(float(a.get_slice("=", 1))).timeout.connect(func() -> void: exit(true))


func _process(delta: float) -> void:
	_timer += delta
	if _timer < CHECK:
		return
	_timer = 0.0
	if active and not _busy and not (_op_tw and _op_tw.is_running()) and not is_equal_approx(_opacity, _want_opacity()):
		_op_tw = create_tween()   # 부르기 시작 · 끝 → 투명도 (0.25초). 들어가기 · 나가기를 막지 않게 _busy 는 안 씀
		_op_tw.tween_method(_set_opacity, _opacity, _want_opacity(), FADE)
	if "--mini-probe" in Game.dev_args() and FileAccess.file_exists("user://mini_tray_click"):   # 개발용: 트레이 클릭 흉내
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://mini_tray_click"))
		print("[MINI]   (트레이 클릭 흉내)")
		exit(true)
		return
	if _busy or "--mini-now" in Game.dev_args():
		return
	var allowed: bool = Game.settings.get("mini_mode", true) and not Game.runtime.hidden \
			and int(Game.settings.window_mode) != 1
	if not allowed:
		_since = 0.0
		if active:
			exit()
		return
	var cov := coverage()
	if "--mini-probe" in Game.dev_args():   # 개발용: 가림 비율 출력
		print("[MINI] 가림 %d%% (표본 %d개)" % [int(cov * 100), _screen_samples().size()])
	var covered := cov >= THRESHOLD
	if _suppress:
		if not covered:
			_suppress = false
		return
	if covered != active:
		_since += CHECK
		if _since >= DELAY:
			_since = 0.0
			if covered:
				enter()
			else:
				exit()
	else:
		_since = 0.0


## 원래 섬 자리 중 다른 창에 덮인 비율 (0~1)
## 평소: 이 창보다 위에 있는 창들 / 미니 모드: 기억해 둔 "섬 위의 창"들 (뒤에 있던 창은 세지 않음)
func coverage() -> float:
	var pts := _samples if active else _screen_samples()
	if pts.is_empty():
		return 0.0
	var frac := _frac(pts, PackedInt32Array(layer.call("RectsOf", _above if active else PackedInt64Array(layer.call("AboveHandles")))))
	if active:
		# 미니 동안 사용자가 앞으로 꺼낸 창도 원래 섬보다 위에 옴 → 기억.
		# 단, 덮던 창이 이미 비켰다면 그때 앞으로 온 창은 Windows가 자동으로 활성화한 것 → 세지 않음
		var fg: int = layer.call("ForegroundHandle")
		if fg != 0 and not fg in _above and frac >= THRESHOLD:
			_above.append(fg)
	return frac


func _frac(pts: PackedVector2Array, rects: PackedInt32Array) -> float:
	if rects.is_empty():
		return 0.0
	var hit := 0
	for p in pts:
		for i in range(0, rects.size(), 4):
			if p.x >= rects[i] and p.y >= rects[i + 1] and p.x < rects[i + 2] and p.y < rects[i + 3]:
				hit += 1
				break
	return float(hit) / pts.size()


## 지금 섬 윤곽(클릭 영역) 안의 표본 점들 → 화면 좌표
func _screen_samples() -> PackedVector2Array:
	var hull: PackedVector2Array = window_ctl.get_hull()
	var wp := Vector2(DisplayServer.window_get_position())
	var out := PackedVector2Array()
	if hull.size() < 3:
		var sz := Vector2(DisplayServer.window_get_size())
		hull = PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)])
	var box := Rect2(hull[0], Vector2.ZERO)
	for q in hull:
		box = box.expand(q)
	for iy in 12:
		for ix in 12:
			var p := box.position + box.size * Vector2((ix + 0.5) / 12.0, (iy + 0.5) / 12.0)
			if Geometry2D.is_point_in_polygon(p, hull):
				out.append(wp + p)
	return out


func enter() -> void:
	if active or _busy:
		return
	_busy = true
	_samples = _screen_samples()
	_above = PackedInt64Array(layer.call("AboveHandles"))
	_orig_pos = DisplayServer.window_get_position()
	layer.call("SetClickThrough", true)   # 클릭 통과 + 창 전체 투명도(층 창) 켜기 → 서서히 사라짐
	await _fade_to(0.0)
	active = true
	Game.runtime.mini = true
	ui.visible = false
	main.mini_k = MINI_K
	main._update_layout()
	layer.call("SetBottom", false)   # 바탕화면 고정이었다면 잠시 풀기 (맨 아래로 다시 보내지 않게)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	window_ctl.mini = true
	window_ctl.update_passthrough()
	var scr := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	_mini_size = DisplayServer.window_get_size()
	DisplayServer.window_set_position(scr.end - _mini_size - MARGIN)
	_style(true)   # "항상 위"를 켜면 Godot가 창 스타일을 다시 써서 클릭 통과가 풀림 → 다시 켬
	Engine.max_fps = Game.effective_fps()
	await _fade_to(_want_opacity())
	_busy = false
	print("[MINI] 미니 모드 (가림 %d%%)" % int(coverage() * 100))
	if "--mini-now" in Game.dev_args():   # 점검: 미니 섬 가운데를 클릭하면 뒤 창으로 가는지
		var c := DisplayServer.window_get_position() + DisplayServer.window_get_size() / 2
		print("[MINI] 클릭 통과 %s · 창 %s %s" % [not layer.call("IsMineAt", c.x, c.y), DisplayServer.window_get_position(), DisplayServer.window_get_size()])


## manual = 트레이로 꺼냄 → 앞으로 가져오고, 가림이 한 번 풀릴 때까지 다시 들어가지 않음
func exit(manual := false) -> void:
	if not active or _busy:
		return
	_busy = true
	await _fade_to(0.0)
	active = false
	Game.runtime.mini = false
	window_ctl.mini = false
	main.mini_k = 0.0
	var k_before: float = main._layout_k
	main._layout_k = -1.0   # "이미 같은 크기"로 보고 건너뛰지 않게 → 항상 원래 크기로 다시 맞춤
	main._update_layout()
	if DisplayServer.window_get_size() == _mini_size:   # 그래도 그대로면 한 번 더 직접 (로그에 남김)
		print("[MINI] 창 크기 복구를 다시 시도 (배율 %.2f)" % main._layout_k)
		get_window().size = Vector2i(Vector2(main.BASE_SIZE.x + main._extra.x + main._extra.y, main.BASE_SIZE.y) * main._layout_k)
	if "--mini-probe" in Game.dev_args():
		print("[MINI]   복귀 배율 %.2f → %.2f, 창 %s" % [k_before, main._layout_k, DisplayServer.window_get_size()])
	DisplayServer.window_set_position(_orig_pos)
	Game.settings.window_pos = [_orig_pos.x, _orig_pos.y]   # 다음 실행도 원래 자리에서
	window_ctl.set_mode(int(Game.settings.window_mode))
	_style(true)   # 원래 모드로 바꾸며 풀린 층 창을 다시 켜서 서서히 나타나게
	if manual:
		_suppress = true
		if int(Game.settings.window_mode) == 0:
			layer.call("BringToFront")
	ui._apply_visibility()
	window_ctl.rebuild_static_shape()
	Engine.max_fps = Game.effective_fps()
	await _fade_to(1.0)
	layer.call("SetClickThrough", false)
	_busy = false
	print("[MINI] 원래 섬으로%s · 창 %s %s" % [" (트레이)" if manual else "", DisplayServer.window_get_position(), DisplayServer.window_get_size()])


## 미니 섬 투명도: 창구에서 부르는 직원이 있으면 1.0, 아니면 설정값
func _want_opacity() -> float:
	return want_opacity(float(Game.settings.get("mini_opacity", 0.7)), main.routine.shown if main and main.routine else {})


static func want_opacity(setting: float, shown: Dictionary) -> float:
	return 1.0 if OfficeRoutine.calling(shown) > 0 else setting


## 클릭 통과 + 창 전체 투명도(층 창) 다시 적용 — 지금 투명도 유지
func _style(on: bool) -> void:
	layer.call("SetClickThrough", on)
	if on:
		layer.call("SetOpacity", _opacity)


func _fade_to(target: float) -> void:
	if _op_tw:
		_op_tw.kill()
	var tw := create_tween()
	tw.tween_method(_set_opacity, _opacity, target, FADE)
	await tw.finished


func _set_opacity(v: float) -> void:
	_opacity = v
	layer.call("SetOpacity", v)
