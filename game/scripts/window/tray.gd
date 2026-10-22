extends Node
## 작업 표시줄 트레이 아이콘 + 전체 화면 앱 감지
##   트레이 왼쪽 클릭: 섬 보이기/숨기기
##   트레이 오른쪽 클릭: 섬을 보이고 설정 패널 열기 (바탕화면 고정 모드처럼 키보드가 안 될 때도 조작 가능)
##   내 차례 15초 (창구에서 부름) 직원이 있으면 아이콘 오른쪽 아래 노랑 점 (5-1, M4 1세션째)
##   다른 프로그램이 같은 모니터에서 전체 화면이면: 섬을 숨기고 화면 갱신을 초당 5번으로 (GPU 절약)

const RasterIcons := preload("res://scripts/util/raster_icons.gd")
const OfficeRoutine := preload("res://scripts/world/office_routine.gd")

var ui: CanvasLayer
var window_layer: Node      ## C# WindowLayer (전체 화면 감지)
var mini: Node              ## 미니 모드 — 왼쪽 클릭이면 바로 원래 섬으로
var routine: Node           ## 직원 일과 (office_routine.gd) — 창구에서 부르는 수 → 노랑 점

var _tray: StatusIndicator
var _user_hidden := false    ## 사용자가 트레이로 숨김
var _fs_hidden := false      ## 전체 화면 앱 때문에 숨김
var _fs_override := false    ## 전체 화면 중이어도 사용자가 트레이로 꺼냄 (전체 화면이 끝나면 해제)
var _timer := 0.0
var _dot := false            ## 지금 노랑 점이 붙어 있나


func _ready() -> void:
	_tray = StatusIndicator.new()
	_tray.icon = RasterIcons.get_texture("office", 32)
	_tray.tooltip = ProjectSettings.get_setting("application/config/name")
	_tray.pressed.connect(_on_pressed)
	add_child(_tray)


var _last_press := {}           ## 버튼 → 마지막으로 처리한 시각(ms)


func _on_pressed(button: int, _pos: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	# Windows는 한 번 클릭에 신호를 두 번 보낼 때가 있음 → 0.4초 안의 같은 버튼은 무시
	if now - int(_last_press.get(button, -10000)) < 400:
		return
	_last_press[button] = now
	if button == MOUSE_BUTTON_LEFT and mini and mini.active:
		mini.exit(true)
		return
	if button == MOUSE_BUTTON_LEFT:
		if _fs_hidden and not _fs_override:   # 전체 화면 때문에 숨은 상태 → 꺼내기
			_fs_override = true
			_user_hidden = false
		else:
			_user_hidden = not _user_hidden
	else:
		if mini and mini.active:   # 오른쪽 클릭: 미니 모드면 먼저 원래 섬으로
			await mini.exit(true)
		_user_hidden = false
		_fs_override = _fs_hidden
		if not Game.settings.ui_visible:
			Game.set_setting("ui_visible", true)
		if ui.panel_id != "gear":
			ui.open_panel("gear")
	_apply()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.5:   # 0.5초마다 확인 → 전체 화면을 켜고 끌 때 거의 바로 반응
		return
	_timer = 0.0
	var dot := routine != null and OfficeRoutine.calling(routine.shown) > 0
	if dot != _dot:
		_dot = dot
		_tray.icon = RasterIcons.get_texture("office_turn" if dot else "office", 32)
	var fs: bool = Game.settings.get("pause_fullscreen", true) and window_layer.call("IsFullscreenAppRunning")
	if fs != _fs_hidden:
		_fs_hidden = fs
		if not fs:
			_fs_override = false
		_apply()


func _apply() -> void:
	var hide := _user_hidden or (_fs_hidden and not _fs_override)
	window_layer.call("SetHidden", hide)   # Godot의 visible=false는 메인 창에 안 먹혀서 Windows 기능 사용
	Game.runtime.hidden = hide
	Engine.max_fps = Game.effective_fps()
