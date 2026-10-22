extends Node
## 게임 안 한 줄 명령 (로드맵 ⑤) 자동 점검: `bash tools/offscreen_test.sh --command-check [--diameter=N]` → [SCENARIO] 줄
## 가짜 claude (.bat) 로 돌려서 토큰 0 · 진짜 claude 는 한 번도 안 부름. 임시 폴더만 씀 (사용자 .claude · .skyoffice 안 건드림)

const CommandRunner := preload("res://scripts/world/command_runner.gd")
const AgentWatch := preload("res://scripts/world/agent_watch.gd")
const AgentState := preload("res://scripts/world/agent_state.gd")

var main: Node3D
var _tally := [0, 0]


func check(name: String, cond: bool, info := "") -> void:
	_tally[0 if cond else 1] += 1
	print("[SCENARIO] %s 명령 %s %s" % ["✔" if cond else "✘", name, info])


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	if "--command-real" in Game.dev_args():   # 진짜 claude 한 번 (토큰 약 $0.15) — 사용자 허락 뒤에만
		await _real()
		main.quit_game()
		return
	_pure()
	var tmp := ProjectSettings.globalize_path("user://").path_join("cmd_check_%d" % OS.get_process_id())   # 임시 폴더(TEMP) 는 직원 폴더에서 빠지는 이름이라 못 씀
	_rm(tmp)
	DirAccess.make_dir_recursive_absolute(tmp)
	_paths(tmp)
	await _runs(tmp)
	await _ui(tmp)
	_rm(tmp)
	DirAccess.remove_absolute(_ps_path)
	print("[SCENARIO] 명령 결과: 성공 %d / 실패 %d" % [_tally[0], _tally[1]])
	main.quit_game()


# ------------------------------------------------------------------ 순수: 인자 · 입력 정리 · 결과 해석
func _pure() -> void:
	var a := CommandRunner.args()
	var s := " ".join(a)
	check("인자: 읽기만 (dontAsk + Read(./**)) · 5턴 · $0.50 · 세션 저장 안 함 · 쓰기/실행/우회 없음",
			"--permission-mode dontAsk" in s and "--allowedTools Read(./**)" in s and "--max-turns 5" in s and "--max-budget-usd 0.50" in s
			and "--no-session-persistence" in s and "-p" in a and "--output-format json" in s
			and not ("bypass" in s.to_lower() or "dangerously" in s or "Bash" in s or "Edit" in s or "Write" in s or "auto" in s.replace("--output", "")),
			s)
	check("입력 정리: 줄바꿈 · 탭 → 공백, 앞뒤 공백 없음, 300자까지", CommandRunner.clean_prompt("  a\nb\tc  ") == "a b c" and CommandRunner.clean_prompt("x".repeat(500)).length() == 300
			and CommandRunner.clean_prompt(" \n ") == "")
	var ok := CommandRunner.parse('{"type":"result","is_error":false,"result":"**첫째**\\n\\n## 둘째\\n`셋째`","total_cost_usd":0.147}', 0)
	check("결과 해석: 성공 = 마크다운 걷고 빈 줄 뺀 줄 · 비용", ok.ok and ok.lines == ["첫째", "둘째", "셋째"] and absf(float(ok.cost) - 0.147) < 1e-6, str(ok.lines))
	var many := "\n".join(range(1, 10).map(func(i): return "줄%d" % i))
	var sm := CommandRunner.summary(many)
	var lg := CommandRunner.summary("가".repeat(200))
	check("요약: 6줄까지 (넘으면 끝에 …) · 한 줄 90자까지", sm.size() == 6 and str(sm[5]).ends_with("…") and str(lg[0]).length() == CommandRunner.LINE_MAX and str(lg[0]).ends_with("…"),
			"%d %d" % [sm.size(), str(lg[0]).length()])
	var login := CommandRunner.parse('{"is_error":true,"result":"Failed to authenticate: OAuth session expired","total_cost_usd":0,"api_error_status":null}', 1)
	var err := CommandRunner.parse('{"is_error":true,"result":"Rate limited\\nsecond","total_cost_usd":0}', 1)
	var bad := CommandRunner.parse("hello", 0)
	var bad2 := CommandRunner.parse("", 1)
	check("결과 해석: 로그인 만료 · 오류 첫 줄 · 알 수 없는 답 · 코드만 있는 실패",
			login.kind == "login" and not login.ok and "/login" in str(login.msg) and err.kind == "error" and err.msg == "Rate limited"
			and bad.kind == "bad" and not bad.ok and bad2.kind == "bad" and "1" in str(bad2.msg))
	check("결과 해석: 취소 · 시간 초과 · 출력 너무 큼",
			CommandRunner.parse("", -1, false, true).kind == "canceled" and CommandRunner.parse("", -1, true).kind == "timeout" and CommandRunner.parse("", -1, false, false, true).kind == "toobig")
	check("비용 한 줄: '약 $0.15 · 추정' · 모르면 빈 글", CommandRunner.cost_text(0.147) == "약 $0.15 · 추정" and CommandRunner.cost_text(-1.0) == "")


# ------------------------------------------------------------------ 폴더 복원 · 직원 폴더 목록 · 일하는 중 막기
var _watch: Node
var _proj_a := ""   ## 임시 프로젝트 폴더 (직원 있음)
var _hash_a := ""


func _paths(tmp: String) -> void:
	var w := tmp.path_join("work")
	_proj_a = w.path_join("한글 프로젝트-a")
	var proj_b := w.path_join("proj_b")
	DirAccess.make_dir_recursive_absolute(_proj_a)
	DirAccess.make_dir_recursive_absolute(proj_b)
	var enc_a := AgentWatch.encode_path(_proj_a.replace("\\", "/"))
	var enc_b := AgentWatch.encode_path(proj_b.replace("\\", "/"))
	check("폴더 복원: 이름 속 '-' · 공백 · 한글이 있어도 전체 경로를 찾음", CommandRunner.real_path(enc_a).to_lower() == _proj_a.replace("\\", "/").to_lower()
			and CommandRunner.real_path("C--없는-폴더-zzz") == "" and CommandRunner.real_path("나쁜이름") == "",
			CommandRunner.real_path(enc_a))
	var pdir := tmp.path_join("projects")
	for d in [enc_a, enc_b, "C--Users-x-AppData-Local-Temp-foo", enc_a + "--claude-worktrees-w1"]:
		DirAccess.make_dir_recursive_absolute(pdir.path_join(d))
	_hash_a = AgentWatch.hash16(enc_a)
	var src := GDScript.new()
	src.source_code = "extends Node\nvar projects := ''\nvar snap := {}\n"
	src.reload()
	_watch = src.new()
	_watch.projects = pdir
	_watch.snap = {"staff": {"staff": [
			{"id": 0, "agent": "claude", "proj": _hash_a, "desk": 0, "leave": false},
			{"id": 1, "agent": "claude", "proj": AgentWatch.hash16(enc_b), "desk": 1, "leave": true},
			{"id": 2, "agent": "codex", "proj": AgentWatch.hash16("C--Users-x-AppData-Local-Temp-foo"), "desk": 2, "leave": false}]},
			"agent": AgentState.empty()}
	add_child(_watch)


# ------------------------------------------------------------------ 실행 (가짜 claude)
func _bat(tmp: String, name: String, lines: Array) -> String:
	var p := tmp.path_join(name + ".bat")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("@echo off\r\n" + "\r\n".join(lines) + "\r\n")
	f.close()
	return p.replace("/", "\\")


func _until(r: Node, secs: float) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	while r.running and Time.get_ticks_msec() - t0 < secs * 1000.0:
		await get_tree().process_frame
	return r.result


var _ps_path := ""


## 이름에 tag 가 들어간 ping.exe 가 살아 있나 (자식 프로세스가 남았는지)
func _ping_alive(tag: String) -> bool:
	if _ps_path == "":
		_ps_path = ProjectSettings.globalize_path("user://").path_join("ping_alive.ps1")
		var f := FileAccess.open(_ps_path, FileAccess.WRITE)
		f.store_string("param($tag)
(Get-CimInstance Win32_Process -Filter \"Name='ping.exe'\" | Where-Object { $_.CommandLine -like \"*$tag*\" } | Measure-Object).Count
")
		f.close()
	var out := []
	OS.execute("powershell", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", _ps_path, tag], out, true)
	return int(str(out[0] if not out.is_empty() else "0").strip_edges()) > 0


func _runs(tmp: String) -> void:
	var r := CommandRunner.new()
	add_child(r)
	r.setup(_watch)
	var prompt := "SECRET_PROMPT_가나다 이 폴더를 요약해 줘"
	# 켜기 전 / 설정 / 폴더 목록
	Game.settings.claude_command = false
	check("꺼짐이 기본: 설정 키 기본값 false · 꺼져 있으면 보내기 거부", Game.settings.has("claude_command") and r.start({"hash": _hash_a}, prompt) == "꺼져 있어요.")
	Game.settings.claude_command = true
	var fl := r.folders()
	check("폴더 목록: 직원(휴직 아님) 있는 실제 폴더만 — 임시 폴더 · worktree · 휴직 · 다른 도구 · 직원 없음 제외", fl.size() == 1 and fl[0].hash == _hash_a
			and str(fl[0].path).to_lower() == _proj_a.replace("\\", "/").to_lower() and fl[0].name == "한글 프로젝트-a" and not fl[0].busy, str(fl))
	check("claude.exe 못 찾음 → 이유 한 줄 (시험 실행에선 진짜 claude 안 부름)", r.unavailable() != "" and r.start({"hash": _hash_a}, prompt) != "")
	# 가짜 claude
	var log_in := tmp.path_join("in.txt").replace("/", "\\")
	var log_cwd := tmp.path_join("cwd.txt").replace("/", "\\")
	var log_args := tmp.path_join("args.txt").replace("/", "\\")
	r.exe_path = _bat(tmp, "ok", [
			"powershell -NoProfile -Command \"[Console]::InputEncoding=New-Object Text.UTF8Encoding($false); $t=[Console]::In.ReadToEnd(); [IO.File]::WriteAllText('%s',$t)\"" % log_in,
			"cd > \"%s\"" % log_cwd,
			"echo %%*> \"%s\"" % log_args,
			"echo {\"type\":\"result\",\"is_error\":false,\"result\":\"line one\\nline two\",\"total_cost_usd\":0.12}"])
	check("빈 글 · 모르는 폴더 거부", r.start({"hash": _hash_a}, "  ") == "한 줄을 적어 주세요." and r.start({"hash": "nope"}, prompt) == "그 폴더에 직원이 없어요.")
	# 일하는 중 막기
	var st := AgentState.reduce(AgentState.empty(), {"t": Time.get_unix_time_from_system(), "event": "UserPromptSubmit", "sess": "s1", "proj": _hash_a})
	_watch.snap.agent = st
	check("같은 폴더 직원이 일하는 중이면 막기", r.is_busy(_hash_a) and r.start({"hash": _hash_a}, prompt) == "그 폴더 직원이 일하는 중이에요.")
	_watch.snap.agent = AgentState.reduce(st, {"t": Time.get_unix_time_from_system(), "event": "Stop", "sess": "s1", "proj": _hash_a})
	check("끝난(done) 직원은 막지 않음", not r.is_busy(_hash_a))
	# 정상 실행
	var err := r.start({"hash": _hash_a}, "SECRET_PROMPT_가나다\n이 폴더를 요약해 줘")
	var second := r.start({"hash": _hash_a}, prompt)
	var res := await _until(r, 20.0)
	check("실행: 시작 → 둘째는 거부(동시 1개) → 결과 성공 · 두 줄 · 비용 $0.12",
			err == "" and second == "이미 하나 돌고 있어요." and res.get("ok", false) and res.lines == ["line one", "line two"] and absf(float(res.cost) - 0.12) < 1e-6 and res.folder == "한글 프로젝트-a" and not r.running,
			str(res))
	var cwd := FileAccess.get_file_as_string(log_cwd).strip_edges() if FileAccess.file_exists(log_cwd) else ""
	check("작업 폴더 = 고른 프로젝트 폴더 (한글 경로 — cmd 가 OEM 코드로 써서 뒷부분만 비교)", cwd.replace("\\", "/").contains("/work/") and cwd.ends_with("-a"), cwd)
	var got_in := FileAccess.get_file_as_string(log_in) if FileAccess.file_exists(log_in) else ""
	check("입력은 stdin 으로, UTF-8 한글 그대로 (줄바꿈은 공백)", got_in.strip_edges() == "SECRET_PROMPT_가나다 이 폴더를 요약해 줘", got_in)
	var got_args := FileAccess.get_file_as_string(log_args).strip_edges() if FileAccess.file_exists(log_args) else ""
	check("인자에는 사용자 글이 없음 (셸 · 명령 주입 없음)", got_args != "" and not ("SECRET" in got_args) and "dontAsk" in got_args and "Read(./**)" in got_args, got_args)
	# 오류들
	r.exe_path = _bat(tmp, "login", ["echo {\"is_error\":true,\"result\":\"Failed to authenticate: OAuth session expired\",\"total_cost_usd\":0}", "exit /b 1"])
	r.start({"hash": _hash_a}, prompt)
	res = await _until(r, 20.0)
	check("로그인 만료 → '로그인이 필요해요' 한 줄", res.get("kind") == "login" and not res.ok, str(res.get("msg")))
	r.exe_path = _bat(tmp, "garbage", ["echo hello world"])
	r.start({"hash": _hash_a}, prompt)
	res = await _until(r, 20.0)
	check("알 수 없는 답 → 오류 한 줄 (그대로 보여 주지 않음)", res.get("kind") == "bad" and not ("hello" in str(res.get("msg"))))
	r.exe_path = _bat(tmp, "big", ["for /L %%i in (1,1,4000) do @echo xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"])
	r.start({"hash": _hash_a}, prompt)
	res = await _until(r, 30.0)
	check("출력이 64KB 를 넘으면 자르고 종료", res.get("kind") == "toobig", str(res.get("kind")))
	# 시간 제한 · 취소 · 프로세스 트리 종료 (자식 ping 이 남지 않음)
	r.exe_path = _bat(tmp, "slow", ["ping -n 61 127.0.0.1 >nul"])
	r.timeout_s = 8   # 자식 확인 (powershell 시작 ~1초) 이 제한 안에 끝나도록 넉넉히
	var t0 := Time.get_ticks_msec()
	r.start({"hash": _hash_a}, prompt)
	await get_tree().create_timer(1.0).timeout
	var child_up := _ping_alive("n 61 127")
	res = await _until(r, 20.0)
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	await get_tree().create_timer(0.5).timeout
	check("시간 제한: 8초 넘으면 멈춤(시험용 줄임) · 자식 프로세스까지 종료", res.get("kind") == "timeout" and took < 15.0 and child_up and not _ping_alive("n 61 127"), "%.1f초 자식살아있었음=%s" % [took, child_up])
	r.timeout_s = 60
	r.start({"hash": _hash_a}, prompt)
	await get_tree().create_timer(1.0).timeout
	r.cancel()
	res = await _until(r, 20.0)
	await get_tree().create_timer(0.5).timeout
	check("취소: 바로 멈춤 · 자식 프로세스 없음 · 다시 보낼 수 있음", res.get("kind") == "canceled" and not r.running and not _ping_alive("n 61 127"))
	# 끊긴 실행이 남긴 유령 세션 (Stop 이 안 옴) 은 막지 않음
	var ghost := AgentState.reduce(AgentState.empty(), {"t": Time.get_unix_time_from_system() - 3, "event": "UserPromptSubmit", "sess": "g1", "proj": _hash_a})
	_watch.snap.agent = ghost
	check("취소 뒤 유령 '일하는 중' 은 막지 않음 · 새 세션이 시작되면 막음", not r.is_busy(_hash_a)
			and (func() -> bool:
				_watch.snap.agent = AgentState.reduce(ghost, {"t": Time.get_unix_time_from_system() + 5, "event": "UserPromptSubmit", "sess": "g2", "proj": _hash_a})
				return r.is_busy(_hash_a)).call())
	_watch.snap.agent = AgentState.empty()
	# 끊은 실행의 직원 퇴근: 진짜 감지기 (임시 폴더) + 이 실행 뒤 생긴 세션만
	var aw := AgentWatch.new()
	add_child(aw)
	aw.setup(tmp.path_join("aw"), "", 4)
	var now := Time.get_unix_time_from_system()
	var put := func(name: String, ev: Dictionary) -> void:
		var ticks := int(float(ev.t) * 1e7) + AgentWatch.TICKS_UNIX
		var f := FileAccess.open(aw.inbox_dir().path_join("%d-1.json" % ticks), FileAccess.WRITE)
		f.store_string(JSON.stringify({"v": 1, "t_start": ticks, "event": ev.event, "sess": name, "proj": _hash_a}))
		f.close()
	put.call("old_user", {"t": now - 600.0, "event": "UserPromptSubmit"})   # 내 실행 전부터 있던 사용자 세션
	r._hash = _hash_a
	r._t0 = now - 1.0
	put.call("mine", {"t": now - 0.5, "event": "UserPromptSubmit"})        # 내 실행이 만든 세션 (Stop 이 안 옴)
	aw.tick(now)
	var before := [AgentState.view(aw.snap.agent.sessions.old_user, now).state, AgentState.view(aw.snap.agent.sessions.mine, now).state]
	r.watch = aw
	r.end_ghosts()
	aw.tick(now + 1.0)
	var after := [AgentState.view(aw.snap.agent.sessions.old_user, now + 1.0).state, AgentState.view(aw.snap.agent.sessions.mine, now + 1.0).state]
	check("끊은 실행의 직원은 퇴근 (내 실행이 만든 세션만 SessionEnd · 원래 있던 사용자 세션은 그대로)",
			before == ["work", "work"] and after[1] == "off" and after[0] == "work", "%s → %s" % [before, after])
	r.watch = _watch
	aw.queue_free()
	# 저장하지 않음
	var snap := JSON.stringify(Game._snapshot())
	check("명령 · 결과는 게임 저장에 없음 (켜짐 값만)", not ("SECRET_PROMPT" in snap) and not ("line one" in snap) and "claude_command" in snap)
	r.clear_result()
	Game.settings.claude_command = false
	r.queue_free()


# ------------------------------------------------------------------ 화면: 꺼짐이면 안 보임 · 동의 카드 · 카드 흐름
func _ui(tmp: String) -> void:
	var cu: Node = main.command_ui
	var cr: Node = main.command_runner
	Game.settings.claude_command = false
	var body := VBoxContainer.new()
	cu.entry(body)
	check("꺼져 있으면 전화 패널에 명령 항목이 아예 없음 (1.0 약속 그대로)", body.get_child_count() == 0)
	var sbody := VBoxContainer.new()
	main.ui.add_child(sbody)
	cu.settings_section(sbody)
	var texts := sbody.get_children().filter(func(n): return n is Button).map(func(b): return (b as Button).text)
	check("설정에 '켜기…' 만 있음 (눌러야 동의 카드)", texts.size() == 1 and "켜기" in str(texts[0]) and not Game.settings.claude_command, str(texts))
	sbody.queue_free()
	var cr_exe: String = cr.exe_path
	cr.exe_path = "C:/fake/claude.exe"   # 켤 수 있는 상태 흉내 (실행은 안 함)
	cu.show_consent()
	await get_tree().process_frame
	check("동의 카드: 바뀌는 점 3줄 + [켜기] [취소]", cu.card != null and cu.card.is_inside_tree()
			and cu.card.find_children("*", "Label", true, false).any(func(l): return "토큰이 쓰여요" in (l as Label).text and "직접 실행" in (l as Label).text and "저장하지 않아요" in (l as Label).text)
			and cu.card.find_children("*", "Button", true, false).size() == 2)
	var on_btn: Button = cu.card.find_children("*", "Button", true, false)[0]
	on_btn.pressed.emit()
	await get_tree().process_frame
	check("[켜기] → 설정 켜짐 · 카드 닫힘 · 전화 패널에 '한 줄 보내기…' 가 생김", Game.settings.claude_command == true and cu.card == null)
	var pb_on := VBoxContainer.new()
	main.phone_ui.panel(pb_on)
	Game.settings.claude_command = false
	var pb_off := VBoxContainer.new()
	main.phone_ui.panel(pb_off)
	Game.settings.claude_command = true
	var has := func(b: Node, t: String) -> bool: return b.find_children("*", "Label", true, false).any(func(l): return (l as Label).text == t)
	check("전화 패널 '인터넷' 줄: 꺼짐 = '안 씀' · 켠 경우만 'Claude 가 씀'", has.call(pb_off, "안 씀") and not has.call(pb_off, "한 줄 보낼 때 Claude 가 씀")
			and has.call(pb_on, "한 줄 보낼 때 Claude 가 씀") and not has.call(pb_on, "안 씀"))
	pb_on.queue_free()
	pb_off.queue_free()
	var body2 := VBoxContainer.new()
	cu.entry(body2)
	check("켜지면 전화 패널에 '한 줄 보내기…' 버튼", body2.get_children().any(func(n): return n is Button and "한 줄 보내기" in (n as Button).text))
	# 입력 → 확인 카드 (가짜 폴더)
	cu.demo = [{"name": "SkyOffice", "path": "C:/y", "hash": "b", "busy": true}, {"name": "OverLand", "path": "C:/z", "hash": "c", "busy": false}]
	cu.sel = ""
	cu.draft = "SECRET 질문"
	cu.show_input()
	await get_tree().process_frame
	var btns: Array = cu.card.find_children("*", "Button", true, false).filter(func(b): return "●" in (b as Button).text or "○" in (b as Button).text)
	check("입력 카드: 일하는 중 폴더는 눌러도 못 고름(비활성) · 쉬는 폴더가 자동 선택", btns.size() == 2 and (btns[0] as Button).disabled and "일하는 중" in (btns[0] as Button).text and cu.sel == "c" and "●" in (btns[1] as Button).text)
	cu.show_confirm()
	await get_tree().process_frame
	var ctext := " ".join(cu.card.find_children("*", "Label", true, false).map(func(l): return (l as Label).text))
	check("확인 카드: 폴더 이름 · 토큰 쓰임 · 읽기만 · 글이 Claude 로 감 + [보내기] [돌아가기]", "OverLand" in ctext and "토큰이 쓰여요" in ctext and "읽기만" in ctext and "Claude 로 보내져요" in ctext
			and cu.card.find_children("*", "Button", true, false).size() == 2)
	cu._shut()
	cu.demo = []
	cu.draft = ""
	# 결과 카드: 닫으면 지움
	cr.result = {"ok": true, "kind": "ok", "cost": 0.147, "lines": ["하나", "둘"], "folder": "x"}
	cu.show_result()
	await get_tree().process_frame
	var rtext := " ".join(cu.card.find_children("*", "Label", true, false).map(func(l): return (l as Label).text))
	check("결과 카드: 요약 줄 + '약 $0.15 · 추정'", "하나" in rtext and "둘" in rtext and "약 $0.15 · 추정" in rtext)
	(cu.card.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	await get_tree().process_frame
	check("[닫기] → 결과를 메모리에서 지움 · 카드 닫힘", cr.result.is_empty() and cu.card == null)
	# 화면 흐름 전체: 보내기 → 읽는 중 카드 → 끝나면 결과 카드 (가짜 claude)
	var w0 = cr.watch
	cr.watch = _watch
	cr.exe_path = _bat(tmp, "ui_ok", ["echo {\"is_error\":false,\"result\":\"ui line\",\"total_cost_usd\":0.01}"])
	cu.sel = _hash_a
	cu.draft = "질문"
	cu._send()
	await get_tree().process_frame
	var running_card: bool = cu.card != null and cu._wait_label != null and cr.running
	await _until(cr, 20.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var done_text := " ".join(cu.card.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)) if cu.card != null else ""
	check("화면 흐름: 보내기 → '읽는 중' 카드(취소 있음) → 끝나면 결과 카드로 바뀜", running_card and "ui line" in done_text and "약 $0.01 · 추정" in done_text, done_text.left(60))
	cr.watch = w0
	cu._shut()
	cr.clear_result()
	cu._turn_off()
	check("끄기 → 설정 꺼짐", Game.settings.claude_command == false)
	cr.exe_path = cr_exe
	Game.settings.claude_command = false


func _rm(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_rm(dir.path_join(d))
	DirAccess.remove_absolute(dir)


# ------------------------------------------------------------------ 진짜 claude 1번 (`--command-real`): 게임 코드 그대로, 폴더 = tools/sandbox/probe5
func _real() -> void:
	var probe := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("tools/sandbox/probe5")
	var tmp := ProjectSettings.globalize_path("user://").path_join("cmd_real_%d" % OS.get_process_id())
	var enc := AgentWatch.encode_path(probe)
	DirAccess.make_dir_recursive_absolute(tmp.path_join(enc))
	var h := AgentWatch.hash16(enc)
	var src := GDScript.new()
	src.source_code = "extends Node
var projects := ''
var snap := {}
"
	src.reload()
	_watch = src.new()
	_watch.projects = tmp
	_watch.snap = {"staff": {"staff": [{"id": 0, "agent": "claude", "proj": h, "desk": 0, "leave": false}]}, "agent": AgentState.empty()}
	add_child(_watch)
	var r := CommandRunner.new()
	add_child(r)
	r.setup(_watch)
	Game.settings.claude_command = true
	print("[SCENARIO] 진짜 claude: 경로 %s · 폴더 목록 %s" % [r.claude_exe(), str(r.folders().map(func(f): return f.name))])
	var t0 := Time.get_ticks_msec()
	var err := r.start({"hash": h}, "Read hello.txt and quote its content in one line.")
	var res := await _until(r, 150.0)
	print("[SCENARIO] 진짜 claude: 시작='%s' %.1f초 결과=%s" % [err, (Time.get_ticks_msec() - t0) / 1000.0, str(res)])
	check("진짜 claude: 성공 · 폴더 안 파일 읽음 · 비용 표시", err == "" and res.get("ok", false) and "hello from probe5" in " ".join(res.get("lines", [])) and float(res.get("cost", -1.0)) > 0.0)
	var jl := OS.get_environment("USERPROFILE").path_join(".claude/projects").path_join(enc)
	check("진짜 claude: Claude 쪽에 대화 기록(.jsonl) 안 남음", not DirAccess.dir_exists_absolute(jl), jl)
	_rm(tmp)
	print("[SCENARIO] 명령 결과: 성공 %d / 실패 %d" % [_tally[0], _tally[1]])
