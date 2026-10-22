extends SceneTree
## 개발용: 소리 파일이 반복 재생 설정으로 불러와지는지 확인 (godot --headless -s)
func _init() -> void:
	for n in ["bgm", "ambience"]:
		var s: AudioStreamWAV = load("res://assets/sounds/%s.wav" % n)
		print("[SOUND] %s 길이 %.1f초, 반복=%s" % [n, s.get_length(), s.loop_mode == AudioStreamWAV.LOOP_FORWARD])
	quit()
