extends Node
## 자리 비움 감지 + 저전력 모드
##   자리 비움: 키보드·마우스 입력이 설정한 시간(분) 넘게 없으면 섬이 쉼 (낮밤 force_sleep) → 돌아오면 원래대로
##   저전력: 배터리로 동작 중(또는 '항상')이면 그림자·SSAO 끄고 화면 갱신을 15로

var window_layer: Node          ## C# WindowLayer
var day_night: Node
var sun: DirectionalLight3D
var env: Environment

var away := false
var _away_since := 0.0
var _timer := 0.0


func _ready() -> void:
	Game.settings_changed.connect(_check_power)
	_check_power.call_deferred()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 3.0:
		return
	_timer = 0.0
	_check_idle()
	_check_power()


func _check_idle() -> void:
	var idle: float = window_layer.call("GetIdleSeconds")
	var limit := float(Game.settings.idle_minutes) * 60.0
	if not away and Game.settings.idle_detect and idle >= limit:
		away = true
		_away_since = Time.get_unix_time_from_system() - idle
		day_night.force_sleep = true
		Game.away_started.emit()
	elif away and (idle < 3.0 or not Game.settings.idle_detect):
		away = false
		day_night.force_sleep = false
		var minutes := int((Time.get_unix_time_from_system() - _away_since) / 60.0)
		Game.away_ended.emit(minutes)   # '돌아오면 요약' 은 M5


func _check_power() -> void:
	var mode: String = Game.settings.low_power
	var low := mode == "on" or (mode == "auto" and bool(window_layer.call("IsOnBattery")))
	if low != Game.runtime.low_power:
		Game.runtime.low_power = low
		if low:
			Game.toast.emit("저전력 모드: 그림자와 효과를 줄였어요")
	if sun:
		sun.shadow_enabled = not low
	if env:
		env.ssao_enabled = not low
	Engine.max_fps = Game.effective_fps()
