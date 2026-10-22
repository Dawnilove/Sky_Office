"""bell.exe 시험 (가짜 stdin → 시험용 inbox). 사용: python tools/bell_test.py <시험빌드 bell.exe 경로>
시험 빌드 = -p:DefineConstants=TESTINBOX (SKYOFFICE_TEST_INBOX 로 inbox 위치 변경, 배포 빌드엔 없음)."""
import json, os, subprocess, sys, tempfile, glob, hashlib

exe = sys.argv[1]
SECRET = "SECRET_MARKER"
inbox = tempfile.mkdtemp()
env = dict(os.environ, SKYOFFICE_TEST_INBOX=inbox)


def h(s):
    return hashlib.sha256(s.encode()).hexdigest()[:16]


def run(obj, *args, raw=None):
    for f in glob.glob(inbox + "/*.json"):
        os.remove(f)
    p = subprocess.run([exe, *args], input=raw if raw is not None else json.dumps(obj).encode("utf-8"), env=env, capture_output=True)
    assert p.returncode == 0 and p.stdout == b"" and p.stderr == b"", (p.returncode, p.stdout, p.stderr)
    fs = glob.glob(inbox + "/*.json")
    assert len(fs) == 1, fs
    text = open(fs[0], encoding="utf-8").read()
    assert SECRET not in text, "내용이 새어 나옴: " + text
    return json.loads(text)


tp = r"C:\Users\x\.codex\sessions\2026\10\22\rollout-2026-10-22T18-29-06-abc.jsonl"
base = {"session_id": "sid1", "turn_id": "t1", "transcript_path": tp, "cwd": r"C:\w\SkyOffice", "model": "gpt-5.1-codex", "permission_mode": "default",
        "prompt": SECRET, "tool_input": {"command": SECRET}, "tool_response": SECRET, "last_assistant_message": SECRET, "agent_transcript_path": SECRET}

for ev in ["SessionStart", "UserPromptSubmit", "PostToolUse", "Stop", "SessionEnd"]:
    r = run(dict(base, hook_event_name=ev), "--agent", "codex")
    assert r["event"] == ev and r["agent"] == "codex" and r["model"] == "gpt-5.1-codex", r
    assert r["proj"] == h("codex") and r["sess"] == h("rollout-2026-10-22T18-29-06-abc"), r

r = run(dict(base, hook_event_name="Interrupt"), "--agent", "codex")
assert r["event"] == "Stop" and r["is_interrupt"] is True, r

r = run(dict(base, hook_event_name="Stop", transcript_path=None), "--agent", "codex")   # null → session_id 해시
assert r["sess"] == h("sid1") and r["proj"] == h("codex"), r

r = run(dict(base, hook_event_name="Stop", model="a b;<x>\u00e9" + "z" * 80), "--agent", "codex")
assert r["model"] == "abx" + "z" * 37 and len(r["model"]) == 40, r

# Claude (인자 없음): 기존 동작 그대로, agent 없음. SessionStart 의 model · PostModelSwitch 의 to_model
ctp = r"C:\Users\x\.claude\projects\C--w-SkyOffice\sess-1.jsonl"
r = run({"hook_event_name": "SessionStart", "session_id": "s", "transcript_path": ctp, "source": "startup", "model": "claude-opus-5-5"})
assert "agent" not in r and r["model"] == "claude-opus-5-5" and r["proj"] == h("C--w-SkyOffice") and r["sess"] == h("sess-1"), r
r = run({"hook_event_name": "PostModelSwitch", "session_id": "s", "transcript_path": ctp, "from_model": "a", "to_model": "claude-sonnet-5-5"})
assert r["event"] == "PostModelSwitch" and r["model"] == "claude-sonnet-5-5", r
r = run({"hook_event_name": "Stop", "session_id": "s", "transcript_path": ctp, "prompt": SECRET})
assert "model" not in r and "agent" not in r, r

# 깨진 입력 · 빈 입력도 종료 코드 0 · 출력 0
r = run(None, raw=b"{not json")
assert r.get("parse_error") is True, r
run(None, "--agent", "codex", raw=b"")
print("bell 시험 통과")
