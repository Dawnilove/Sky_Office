extends Node
## 소리: 배경음악 + 환경음 층(낮: 시냇물·모닥불·새 / 밤: 풀벌레 / 비: 빗소리) + 효과음
## res://assets/sounds/ 의 파일을 반복 재생 (.ogg 또는 .wav, .wav 반복은 .import 의 edit/loop_mode=2)
## 기본 파일은 tools/audio/make_sounds.py 로 만든 것 (다른 음원으로 바꾸려면 같은 이름으로 덮어쓰기)

const DIR := "res://assets/sounds/"
const LOOPS := ["bgm", "ambience", "night", "rain"]
const FADE_SPEED := 0.4      ## 환경음 층이 바뀔 때 초당 음량 변화

var day_night: Node          ## 시각·날씨에 따라 환경음 층 섞기
var _players := {}
var _gain := {"ambience": 1.0, "night": 0.0, "rain": 0.0}
var _sfx: AudioStreamPlayer


func _ready() -> void:
	for key in LOOPS:
		var p := AudioStreamPlayer.new()
		p.name = key
		p.stream = _load(key)
		if p.stream is AudioStreamOggVorbis:
			(p.stream as AudioStreamOggVorbis).loop = true
		add_child(p)
		_players[key] = p
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	Game.settings_changed.connect(_apply)
	_apply()


## 종료 준비: 재생을 멈추고 소리 파일을 놓아줌 (종료 시 리소스 정리 경고 방지)
func shutdown() -> void:
	for p in _players.values() + [_sfx]:
		(p as AudioStreamPlayer).stop()
		(p as AudioStreamPlayer).stream = null


func _load(key: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(DIR + key + ext):
			return load(DIR + key + ext)
	return null


func has_files() -> bool:
	return _players.bgm.stream != null or _players.ambience.stream != null


func play_sfx(key: String) -> void:
	var s := _load(key)
	if s:
		_sfx.stream = s
		_sfx.volume_db = linear_to_db(clampf(float(Game.settings.get("alert_volume", 0.7)), 0.001, 1.0))
		_sfx.play()


func _apply() -> void:
	for key in LOOPS:
		var p: AudioStreamPlayer = _players[key]
		var on: bool = Game.settings.bgm if key == "bgm" else Game.settings.ambience
		if p.stream and on and not p.playing:
			p.play()
		elif not on and p.playing:
			p.stop()
	_mix(1.0)


func _process(delta: float) -> void:
	_mix(delta)


## 시각·날씨에 맞춰 환경음 층 음량을 천천히 바꿈
func _mix(delta: float) -> void:
	var night := 0.0
	var raining := false
	if day_night:
		var h: float = day_night.hour
		night = clampf(max(h - 18.5, 6.0 - h) / 2.0, 0.0, 1.0) if (h >= 18.5 or h < 6.0) else 0.0
		raining = day_night.weather() == "rain"
	var want := {"ambience": 1.0 - 0.75 * night, "night": night, "rain": 1.0 if raining else 0.0}
	var vol := clampf(float(Game.settings.volume), 0.001, 1.0)
	for key in _gain:
		_gain[key] = move_toward(_gain[key], want[key], delta * FADE_SPEED)
		var p: AudioStreamPlayer = _players[key]
		p.volume_db = linear_to_db(max(0.0001, vol * 0.55 * _gain[key]))
	_players.bgm.volume_db = linear_to_db(vol)


func panel(ui: CanvasLayer, body: VBoxContainer) -> void:
	if not has_files():
		body.add_child(ui._note("아직 소리 파일이 없어요. assets/sounds/ 폴더에 bgm, ambience (.ogg/.wav)를 넣으면 재생돼요."))
	ui.section(body, "배경음악")
	body.add_child(ui.segment([["켜기", true], ["끄기", false]], Game.settings.bgm, func(v) -> void: Game.set_setting("bgm", v)))
	ui.section(body, "환경음 (창밖 소리 — 낮 · 밤에 따라 바뀜)")
	body.add_child(ui.segment([["켜기", true], ["끄기", false]], Game.settings.ambience, func(v) -> void: Game.set_setting("ambience", v)))
	ui.section(body, "음악 · 환경음 음량")
	body.add_child(_slider("volume", func() -> void: _mix(1.0)))
	ui.section(body, "알림 소리 ('딩') 음량")
	body.add_child(_slider("alert_volume", func() -> void: pass))


func _slider(key: String, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Game.settings.get(key, 0.7))
	s.custom_minimum_size.x = 240
	s.value_changed.connect(func(v: float) -> void:
		Game.settings[key] = v
		on_change.call())
	s.drag_ended.connect(func(_c: bool) -> void: Game.save_game())
	return s
