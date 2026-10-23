extends Node
## 전화 화면 (M5 4세션째): 사장 책상 전화기를 누르면 연결 상태 패널 (8장) — 원인 1줄 · 마지막 신호 · 최근 신호 10개 · 연결 점검 ·
##   해시 확인 · 받는 것 / 저장하는 것 표 · (미개통 · 불통이면) 전화 개통 안내 + 바뀌는 내용 미리 보기
## 폐업 정리 확인 카드 (설정 > 회사 탭 맨 아래에서 엶)
## 승인 버튼 없음 · 노랑 · 빨강 · 카운트다운 · 경고음 없음 (5-6)

const Phone := preload("res://scripts/world/phone.gd")
const STATE_NAME := {"none": "미개통", "on": "개통 · 정상", "broken": "불통"}

var ui: CanvasLayer
var phone: Node
var firm_ui: Node
var office: Node3D
var last_test := ""         ## 연결 점검 결과 (패널에 남김)
var job_msg := ""           ## 개통 명령 결과
var close_card: PanelContainer
var show_detail := false   ## 개통 미리 보기 ①~⑤ 펼침 (사용자: 접어 두기)


func setup(u: CanvasLayer, p: Node, f: Node, o: Node3D) -> void:
	ui = u
	phone = p
	firm_ui = f
	office = o
	ui.register_panel("phone", "전화 · 연결 상태", panel)
	phone.changed.connect(_on_changed)
	phone.job_done.connect(_on_job)
	_on_changed()


func _on_changed() -> void:
	office.set_phone(str(phone.status.state))
	if ui.panel_id == "phone":
		ui.refresh_panel()


## 화면 클릭 → 전화기 근처면 패널 (desktop_window.click_handler). 처리했으면 true
func click(screen: Vector2) -> bool:
	var cam := office.get_viewport().get_camera_3d()
	if cam == null or office.boss.is_empty():
		return false
	var p: Vector3 = office.phone_point()
	if cam.is_position_behind(p):
		return false
	if cam.unproject_position(p).distance_to(screen) > 26.0 * maxf(1.0, office.get_viewport().get_visible_rect().size.y / 740.0):
		return false
	ui.open_panel("phone")
	return true


func _when(t: float) -> String:
	if t <= 0.0:
		return "-"
	var d := Time.get_datetime_dict_from_unix_time(int(t) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	return "%02d:%02d" % [d.hour, d.minute]


static func ago(t: float, now: float) -> String:
	if t <= 0.0:
		return "아직 없음"
	var m := int((now - t) / 60.0)
	if m < 1:
		return "방금"
	if m < 60:
		return "%d분 전" % m
	if m < 1440:
		return "%d시간 전" % (m / 60)
	return "%d일 전" % (m / 1440)


func _line(body: VBoxContainer, text: String, size := 14) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ui.TEXT)
	body.add_child(l)
	return l


## 연결 상태 패널
func panel(body: VBoxContainer) -> void:
	var st: Dictionary = phone.status
	var s := str(st.state)
	_line(body, "전화: %s" % STATE_NAME.get(s, s), 17)
	body.add_child(ui._note(str(st.reason)))
	if bool(st.get("paused", false)):
		body.add_child(ui._note("신호 처리 멈춤 · 직원은 관찰 모드로만 움직여요."))
	if s != "none":
		var sig: Dictionary = phone.signal_times()
		_line(body, "마지막 신호: %s" % ago(float(sig.hook_t), float(sig.now)))
		ui.group(body, "최근 신호 (이벤트 이름 · 시각만)")
		var rec: Array = phone.recent()
		if rec.is_empty():
			body.add_child(ui._note("아직 없음"))
		for r in rec:
			_line(body, "%s   %s" % [_when(float(r[1])), str(r[0])], 13)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(ui.button("연결 점검", func() -> void:
			last_test = str(phone.self_test().msg)
			ui.refresh_panel()))
		body.add_child(row)
		if last_test != "":
			body.add_child(ui._note(last_test))
		ui.group(body, "해시 확인 (게임 안 원본과 비교)")
		var want: Dictionary = Phone.expected()
		for rel in Phone.FILES:
			var v := str((st.files as Dictionary).get(rel, "missing"))
			_line(body, "%s   %s   %s" % [Phone.FILES[rel], {"ok": "같음", "diff": "다름", "missing": "없음"}.get(v, v), str(want[rel]).left(12)], 13)
	if s != "on":
		_install_part(body)
	else:
		_codex_part(body)
	ui.group(body, "받는 것 / 저장하는 것")
	for r in [["받는 것", "신호 종류 · 도구 이름 · 폴더 끝 이름 · 모델 이름"],   # 사용자: 간략하게 (자세한 목록 = README)
			["안 받는 것", "대화 · 명령 · 파일 내용"],
			["저장", "내 PC 안에만 (.skyoffice · 게임 저장)"],
			["인터넷", "한 줄 보낼 때 Claude 가 씀" if bool(Game.settings.get("claude_command", false)) else "안 씀"]]:   # ⑤ 를 켠 경우만 (게임 자체는 안 씀)
		var h := HBoxContainer.new()
		var k := Label.new()
		k.text = r[0]
		k.custom_minimum_size.x = 74
		k.add_theme_font_size_override("font_size", 13)
		k.add_theme_color_override("font_color", ui.ACCENT_DARK)
		h.add_child(k)
		var n: Label = ui._note(r[1])
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		body.add_child(h)


## 전화 개통 안내 + 바뀌는 내용 미리 보기 (8장 첫 실행 · 7-5)
func _install_part(body: VBoxContainer) -> void:
	ui.group(body, "전화 개통 = 내 차례 알림")
	body.add_child(ui._note("개통하면 허락 요청 · 질문을 바로 알아요."))
	var names: Array = []
	var hj = JSON.parse_string(FileAccess.get_file_as_string(Phone.BUNDLE + "hooks.json"))
	if typeof(hj) == TYPE_DICTIONARY:
		names = (hj.hooks as Dictionary).keys()
	body.add_child(ui.button("바뀌는 것 접기 ▴" if show_detail else "바뀌는 것 자세히 ▾", func() -> void:
		show_detail = not show_detail
		ui.refresh_panel()))
	for t in ([] if not show_detail else [
			"① 파일 %d개 → %s" % [Phone.FILES.size(), phone.root().replace("/", "\\")],
			"② Claude Code 명령: 마켓 추가 · 플러그인 설치",
			"③ 훅 %d개 · 출력 없음 · 결정 권한 없음" % names.size(),
			"④ settings.json 은 게임이 안 고침",
			"⑤ 끄기 = 설정 > 회사 > 폐업 정리"]):
		body.add_child(ui._note(t))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var b1: Button = ui.button("개통하기" if phone.busy == "" else "개통 중…", func() -> void:
		job_msg = ""
		if not phone.install():
			job_msg = "claude 명령을 못 찾았어요. [명령 복사]를 써 주세요."
		ui.refresh_panel())
	b1.disabled = phone.busy != ""
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b1)
	var b2: Button = ui.button("명령 복사", func() -> void:
		phone.copy_bundle()
		DisplayServer.clipboard_set(Phone.command_text(phone.install_steps(Phone.claude_side(phone.claude_home))))
		Game.toast.emit("명령 복사함 (PowerShell 에 붙여 넣기)"))
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b2)
	body.add_child(row)
	if job_msg != "":
		body.add_child(ui._note(job_msg))
	body.add_child(ui._note("열린 Claude Code 는 다시 켜면 확실해요."))


## Codex 연결 (선택, 복사 안내): 게임은 Codex 설정 파일을 안 고침
func _codex_part(body: VBoxContainer) -> void:
	ui.group(body, "Codex 연결 (선택)")
	var cs: Dictionary = Phone.codex_side(Phone.codex_home())
	if phone.codex_hooked():
		body.add_child(ui._note("연결됨 · Codex 신호를 받고 있어요."))
	elif not FileAccess.file_exists(phone.bell_path()):
		body.add_child(ui._note("먼저 위에서 전화를 개통해 주세요 (bell 이 있어야 해요)."))
	elif bool(cs.bell):
		body.add_child(ui._note("붙여 넣음 · codex 를 열고 /hooks 에서 직접 믿기 (신뢰) 를 눌러 주세요."))
	elif bool(cs.file):
		body.add_child(ui._note("hooks.json 이 이미 있어요. 덮지 말고 복사한 내용을 합쳐 주세요."))
	else:
		body.add_child(ui._note("복사해서 ~/.codex/hooks.json 으로 저장하세요. 지금은 관찰 모드 (추정)."))
	body.add_child(ui._note("저장 뒤 codex 의 /hooks 에서 새 훅을 직접 믿어야 해요 (안 믿으면 조용히 건너뜀). 명령이 바뀌면 다시 믿기. CLI 만 확인됨."))
	body.add_child(ui.button("Codex 훅 복사", func() -> void:
		DisplayServer.clipboard_set(Phone.codex_snippet(phone.bell_path()))
		Game.toast.emit("복사함 · hooks.json 에 붙여 넣기")))


func _on_job(kind: String, ok: bool, msg: String) -> void:
	if kind == "install":
		job_msg = "개통했어요!" if ok else "개통 실패: %s" % msg
		if ok:
			Game.toast.emit("전화 개통!")
		if ui.panel_id == "phone":
			ui.refresh_panel()
	elif kind == "close":
		if ok or msg == "":
			phone.close_files()
		else:
			_close_fallback(msg)


# ------------------------------------------------------------------ 폐업 정리 (흔적 0)
## 설정 > 회사 탭 맨 아래
func close_section(body: VBoxContainer) -> void:
	ui.group(body, "폐업 정리")
	body.add_child(ui._note("전화기 · 회사 기록 · 설정을 모두 지우고 게임을 꺼요. 되돌릴 수 없어요."))
	body.add_child(ui.button("폐업 정리…", show_close))


func show_close() -> void:
	if close_card:
		return
	ui.close_panel()
	var cv: Array = firm_ui._float_card("폐업 정리")
	close_card = cv[0]
	var v: VBoxContainer = cv[1]
	firm_ui._big_card(close_card, v)
	var lines := "지우는 것\n· 플러그인 · 마켓 (Claude Code)\n· .skyoffice 폴더\n· 게임 저장 · 설정 · 솔트\n· 자동 실행
(Codex hooks.json 에 붙였다면 bell 항목은 직접 지워 주세요)"
	v.add_child(firm_ui._big_note(lines, 14))
	var go := func() -> void:
		firm_ui._close(close_card)
		close_card = null
		Game.toast.emit("폐업 정리 중…")
		phone.close_business()
	firm_ui._big_buttons(v, [["폐업하기", go], ["취소", func() -> void:
		firm_ui._close(close_card)
		close_card = null]])
	v.add_child(firm_ui._big_note("남는 것: 게임 폴더 · 내 사진", 14))
	firm_ui._place(close_card, 0.45)


## claude 명령이 실패 · 없음 → 명령을 보여 주고 직접 붙여 넣은 뒤 파일 정리
func _close_fallback(msg: String) -> void:
	var cv: Array = firm_ui._float_card("폐업 정리 — 직접 한 단계")
	close_card = cv[0]
	var v: VBoxContainer = cv[1]
	firm_ui._big_card(close_card, v)
	v.add_child(firm_ui._big_note("Claude Code 명령 실패 (%s).\n아래 명령을 PowerShell 에 붙여 넣어 주세요." % msg.left(40), 14))
	var cmd := Phone.command_text(phone.uninstall_steps())
	v.add_child(firm_ui._big_note(cmd, 13))
	firm_ui._big_buttons(v, [["명령 복사", func() -> void: DisplayServer.clipboard_set(cmd)],
			["파일 지우고 끝내기", func() -> void: phone.close_files()]])
	firm_ui._place(close_card, 0.45)
