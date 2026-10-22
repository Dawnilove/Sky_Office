extends Node
## 게임 안 한 줄 명령 화면 (로드맵 ⑤ · 설계 docs/v1_2/게임안명령_설계.md): 설정 켜기 + 동의 카드, 사장 책상 전화 패널의 '한 줄 보내기',
##   입력(폴더 고르기 + 한 줄) → 확인 카드 → 읽는 중(취소) → 결과(요약 6줄 + '약 $ · 추정').
## 꺼져 있으면 아무것도 안 보임 (1.0 약속 그대로). 승인 버튼 없음 · 합계 · 목표 · 경고색 없음 (원칙 3 · 4)
## 개발 인자: `--command-card=consent|input|confirm|running|result|login|error` (가짜 데이터 그림, 아무것도 실행 안 함)

const HangulInput := preload("res://scripts/ui/hangul_input.gd")
const CommandRunner := preload("res://scripts/world/command_runner.gd")
const INPUT_FONT := 16

var ui: CanvasLayer
var runner: Node          ## command_runner
var firm_ui: Node         ## 카드 공통 (_float_card · _big_card · _big_note · _big_buttons · _place · _close)
var card: PanelContainer
var sel := ""             ## 고른 폴더 해시
var draft := ""           ## 적던 글 (폴더를 바꿔도 남김)
var err := ""             ## 카드 아래 한 줄 (보낼 수 없는 이유)
var demo: Array = []      ## 개발 인자용 가짜 폴더 목록
var _wait_label: Label


func setup(u: CanvasLayer, r: Node, f: Node) -> void:
	ui = u
	runner = r
	firm_ui = f
	runner.finished.connect(_on_finished)
	set_process(false)
	for a in Game.dev_args():
		if a.begins_with("--command-card="):
			_demo.call_deferred(a.get_slice("=", 1))


# ------------------------------------------------------------------ 설정 (설정 > 회사 탭, firm_ui.close_section 앞에 끼움)
func settings_section(body: VBoxContainer) -> void:
	ui.group(body, "게임에서 Claude 부르기 (선택)")
	var on: bool = runner.enabled()
	body.add_child(ui._note("켜면 사장 책상 전화에서 Claude 에게 한 줄을 보낼 수 있어요. 끄면 아무것도 안 해요."))
	var why: String = runner.unavailable()
	var b: Button = ui.button("켜짐 · 끄기" if on else "켜기…", _turn_off if on else show_consent)
	b.disabled = (not on) and why != ""
	body.add_child(b)
	if b.disabled:
		body.add_child(ui._note(why))


func _turn_off() -> void:
	runner.cancel()
	runner.clear_result()
	_shut()
	Game.set_setting("claude_command", false)
	ui.refresh_panel()


## 켤 때 한 번: 바뀌는 점 3줄
func show_consent() -> void:
	_open("게임에서 Claude 부르기")
	var v: VBoxContainer = card.get_child(0)
	v.add_child(_txt("켜면 이렇게 바뀌어요\n· 게임이 Claude 를 직접 실행해요\n· 보낼 때마다 토큰이 쓰여요\n· 폴더 안 읽기만 하고, 아무것도 저장하지 않아요", 14))
	firm_ui._big_buttons(v, [["켜기", func() -> void:
		_shut()
		Game.set_setting("claude_command", true)
		Game.toast.emit("전화 패널에서 한 줄을 보낼 수 있어요")
		ui.refresh_panel()], ["취소", _shut]])
	_show()


# ------------------------------------------------------------------ 전화 패널 (phone_ui.panel 뒤에 붙임) — 켜졌을 때만 보임
func entry(body: VBoxContainer) -> void:
	if not runner.enabled():
		return
	ui.group(body, "Claude 에게 한 줄 (선택)")
	if runner.running:
		body.add_child(ui.button("읽는 중… 보기", show_running))
	elif not runner.result.is_empty():
		body.add_child(ui.button("결과 보기", show_result))
	else:
		var b: Button = ui.button("한 줄 보내기…", show_input)
		b.disabled = runner.unavailable() != ""
		body.add_child(b)
		if b.disabled:
			body.add_child(ui._note(runner.unavailable()))


# ------------------------------------------------------------------ 카드 공통
func _open(title: String) -> void:
	_shut()
	var cv: Array = firm_ui._float_card(title)
	card = cv[0]
	firm_ui._big_card(card, cv[1])


## 카드 안 글: 회색(SUB) 대신 본문색 — 얇아 보이지 않게 (사용자)
func _txt(text: String, size: int) -> Label:
	var l: Label = firm_ui._big_note(text, size)
	l.add_theme_color_override("font_color", ui.TEXT)
	return l


func _show() -> void:
	firm_ui._place(card, 0.45)


func _shut() -> void:
	if card:
		firm_ui._close(card)
		card = null
	_wait_label = null
	set_process(false)


func _folders() -> Array:
	return demo if not demo.is_empty() else runner.folders()


func _entry() -> Dictionary:
	for f in _folders():
		if str(f.hash) == sel:
			return f
	return {}


# ------------------------------------------------------------------ 1. 입력: 폴더 고르기 + 한 줄
func show_input() -> void:
	_open("Claude 에게 한 줄")
	var v: VBoxContainer = card.get_child(0)
	var fl := _folders()
	if fl.is_empty():
		v.add_child(_txt("직원이 있는 프로젝트가 아직 없어요.\nClaude Code 를 한 번 쓰면 생겨요.", 14))
		firm_ui._big_buttons(v, [["닫기", _shut]])
		_show()
		return
	if _entry().is_empty() or bool(_entry().busy):
		sel = ""
		for f in fl:
			if not bool(f.busy):
				sel = str(f.hash)
				break
	v.add_child(_txt("어느 프로젝트에서 읽을까요?", 14))
	var inp: HangulInput = firm_ui._big_input(CommandRunner.PROMPT_MAX, "무엇을 알아볼까요?", draft)
	inp.font_size = INPUT_FONT   # 창업 화면 큰 입력칸(20) 보다 작게 (사용자)
	inp.get_child(0).custom_minimum_size.y = 40
	inp.get_child(1).custom_minimum_size = Vector2(40, 40)
	for f in fl.slice(0, 8):
		var busy := bool(f.busy)
		var b: Button = ui.button(("● " if str(f.hash) == sel else "○ ") + str(f.name) + ("  (일하는 중)" if busy else ""), func() -> void:
			draft = inp.get_text()
			sel = str(f.hash)
			show_input())
		b.disabled = busy
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(b)
	if fl.size() > 8:
		v.add_child(ui._note("그 밖에 %d곳" % (fl.size() - 8)))
	v.add_child(inp)
	var next := func() -> void:
		draft = inp.get_text()
		if _entry().is_empty():
			err = "프로젝트를 골라 주세요."
			show_input()
		elif CommandRunner.clean_prompt(draft) == "":
			err = "한 줄을 적어 주세요."
			show_input()
		else:
			err = ""
			show_confirm()
	inp.text_submitted.connect(func(_t: String) -> void: next.call())
	firm_ui._big_buttons(v, [["다음", next], ["닫기", _shut]])
	if err != "":
		v.add_child(_txt(err, 14))
	_show()
	inp.grab_input_focus.call_deferred()


# ------------------------------------------------------------------ 2. 확인 카드 (토큰 쓰임 · 폴더 · 읽기만)
func show_confirm() -> void:
	_open("보낼까요?")
	var v: VBoxContainer = card.get_child(0)
	var e := _entry()
	v.add_child(_txt("'%s' 폴더에서 Claude 를 1번 불러요\n· 토큰이 쓰여요 (수 센트~수십 센트 추정)\n· 그 폴더 안 읽기만 해요\n· 입력한 글은 Claude 로 보내져요" % str(e.get("name", "")), 14))
	firm_ui._big_buttons(v, [["보내기", _send], ["돌아가기", show_input]])
	_show()


func _send() -> void:
	err = runner.start(_entry(), draft)
	if err != "":
		show_input()
		return
	draft = ""
	show_running()


# ------------------------------------------------------------------ 3. 읽는 중 (취소)
func show_running() -> void:
	_open("Claude 가 읽는 중")
	var v: VBoxContainer = card.get_child(0)
	_wait_label = _txt("", 14)
	v.add_child(_wait_label)
	firm_ui._big_buttons(v, [["취소", func() -> void: runner.cancel()], ["숨기기", _shut]])
	_tick()
	_show()
	set_process(true)


func _process(_d: float) -> void:
	_tick()


func _tick() -> void:
	if _wait_label and is_instance_valid(_wait_label):
		_wait_label.text = "%d초 · 최대 %d초까지 기다려요" % [(Time.get_ticks_msec() - runner.started_ms) / 1000, CommandRunner.TIMEOUT_S]


func _on_finished(_res: Dictionary) -> void:
	set_process(false)
	if card != null and _wait_label != null:
		show_result()
	else:
		Game.toast.emit("Claude 가 끝났어요 — 전화 패널에서 결과 보기")
	if ui.panel_id == "phone":
		ui.refresh_panel()


# ------------------------------------------------------------------ 4. 결과 (요약 · 비용 한 줄 · 닫으면 지움)
func show_result() -> void:
	var res: Dictionary = runner.result
	_open("Claude 의 답" if bool(res.get("ok", false)) else "끝나지 않았어요")
	var v: VBoxContainer = card.get_child(0)
	if bool(res.get("ok", false)):
		if (res.lines as Array).is_empty():
			v.add_child(_txt("(빈 답)", 14))
		for l in res.lines:
			var lb: Label = ui._note(str(l))
			lb.add_theme_font_size_override("font_size", 14)
			lb.add_theme_color_override("font_color", ui.TEXT)
			lb.custom_minimum_size.x = 372
			v.add_child(lb)
	else:
		var m: Label = ui._note(str(res.get("msg", "")))
		m.add_theme_font_size_override("font_size", 14)
		m.add_theme_color_override("font_color", ui.TEXT)
		m.custom_minimum_size.x = 372
		v.add_child(m)
	var ct: String = CommandRunner.cost_text(float(res.get("cost", -1.0)))
	if ct != "":
		v.add_child(ui._note(ct))
	firm_ui._big_buttons(v, [["닫기", func() -> void:
		runner.clear_result()
		_shut()
		if ui.panel_id == "phone":
			ui.refresh_panel()]])
	_show()


# ------------------------------------------------------------------ 개발 인자 (그림): 아무것도 실행 안 함
func _demo(which: String) -> void:
	demo = [{"name": "Physical-AI-Learnig-Machine", "path": "C:/x", "hash": "a", "busy": false},
			{"name": "SkyOffice", "path": "C:/y", "hash": "b", "busy": true},
			{"name": "OverLand", "path": "C:/z", "hash": "c", "busy": false}]
	sel = "a"
	draft = "이 프로젝트가 뭘 하는지 세 줄로 알려줘"
	match which:
		"consent": show_consent()
		"input": show_input()
		"confirm": show_confirm()
		"running":
			runner.started_ms = Time.get_ticks_msec() - 37000
			show_running()
			_wait_label.text = "37초 · 최대 %d초까지 기다려요" % CommandRunner.TIMEOUT_S
		"result":
			runner.result = {"ok": true, "kind": "ok", "cost": 0.147, "lines": ["이 프로젝트는 로봇 학습용 파이썬 · C 예제 모음이에요.", "폴더마다 주차별 과제가 들어 있어요.", "PyQt 화면 예제가 가장 많아요."]}
			show_result()
		"login", "error":
			runner.result = {"ok": false, "kind": which, "cost": -1.0, "msg": "Claude 로그인이 필요해요. 터미널에서 claude 를 열어 /login 해 주세요." if which == "login" else "시간이 넘어 멈췄어요 (120초)."}
			show_result()
