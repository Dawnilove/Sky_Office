// 하늘 오피스 bell.exe — Claude Code 훅 입력(stdin JSON)에서 허용한 필드만 꺼내
// %USERPROFILE%\.skyoffice\inbox\<UTC 100ns>-<pid>.json 으로 쓴다. (PLAN 7-1, 7-2)
// 규칙: stdout/stderr 0바이트, 항상 종료 코드 0, 네트워크·로그 없음.
// --record : 시험용. 입력의 '모양'(키 이름·값 종류·길이)만 추가로 기록하고 값은 버린다.

using System.Buffers;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

static class Bell
{
    static int Main(string[] args)
    {
        try { Run(args); } catch { /* 어떤 실패도 Claude Code 에 영향 주지 않음 */ }
        return 0;
    }

    static void Run(string[] args)
    {
        long tStart = 0;
        try { tStart = Process.GetCurrentProcess().StartTime.ToUniversalTime().Ticks; } catch { }

        bool record = Array.IndexOf(args, "--record") >= 0;
        byte[] input = ReadAll(Console.OpenStandardInput());

        var buf = new ArrayBufferWriter<byte>(1024);
        using (var j = new Utf8JsonWriter(buf))
        {
            j.WriteStartObject();
            j.WriteNumber("v", 1);
            j.WriteNumber("t_start", tStart);
            // 7-5 확인용: 실제로 실행된 bell.exe 위치 종류 (경로 자체는 쓰지 않음)
            string exe = (Environment.ProcessPath ?? "").Replace('/', '\\');
            j.WriteString("exe_loc",
                exe.Contains(@"\.skyoffice\plugin\", StringComparison.OrdinalIgnoreCase) ? "skyoffice" :
                exe.Contains(@"\.claude\plugins\cache\", StringComparison.OrdinalIgnoreCase) ? "cache" : "other");
            try
            {
                using var doc = JsonDocument.Parse(input);
                WriteAllowed(j, doc.RootElement);
                if (record) WriteShape(j, doc.RootElement);
            }
            catch
            {
                j.WriteBoolean("parse_error", true);
                j.WriteNumber("in_len", input.Length);
            }
            j.WriteNumber("t_write", DateTime.UtcNow.Ticks);
            j.WriteEndObject();
        }

        string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".skyoffice", "inbox");
        Directory.CreateDirectory(dir);
        string name = DateTime.UtcNow.Ticks.ToString("D19") + "-" + Environment.ProcessId;
        string tmp = Path.Combine(dir, "." + name + ".tmp");
        File.WriteAllBytes(tmp, buf.WrittenSpan.ToArray());
        File.Move(tmp, Path.Combine(dir, name + ".json"));
    }

    static byte[] ReadAll(Stream s)
    {
        using var ms = new MemoryStream();
        s.CopyTo(ms);
        return ms.ToArray();
    }

    // 허용한 필드만 (PLAN 7-2). 나머지(프롬프트·명령·파일 내용 등)는 읽지 않고 버린다.
    static void WriteAllowed(Utf8JsonWriter j, JsonElement r)
    {
        if (r.ValueKind != JsonValueKind.Object) return;

        PutEnum(j, r, "hook_event_name", "event");
        PutEnum(j, r, "notification_type", "ntype");
        PutEnum(j, r, "source", "source");          // SessionStart
        PutEnum(j, r, "reason", "reason");          // SessionEnd
        PutEnum(j, r, "trigger", "trigger");        // PreCompact
        PutEnum(j, r, "permission_mode", "pmode");
        PutEnum(j, r, "agent_type", "agent_type");  // Subagent*
        // StopFailure 의 오류 종류만. PostToolUseFailure 의 error 는 명령 출력이 든 자유 문장이라 절대 쓰지 않음
        if (Str(r, "hook_event_name") == "StopFailure" && Str(r, "error") is string ek && IsEnumWord(ek))
            j.WriteString("error_kind", ek);

        if (Str(r, "tool_name") is string tool)
            j.WriteString("tool", tool.StartsWith("mcp__", StringComparison.Ordinal) ? "MCP" : Clean(tool));

        if (Str(r, "session_id") is string sid) j.WriteString("sid", Hash(sid));
        if (Str(r, "agent_id") is string aid) j.WriteString("aid", Hash(aid));

        // 직원 키 (7-3): 프로젝트 = transcript 부모 폴더 이름 해시, 세션 = 파일 이름 해시
        if (Str(r, "transcript_path") is string tp && tp.Length > 0)
        {
            string trimmed = tp.TrimEnd('\\', '/');
            string? parent = Path.GetDirectoryName(trimmed);
            j.WriteString("proj", Hash(parent is null ? "" : Path.GetFileName(parent)));
            j.WriteString("sess", Hash(Path.GetFileNameWithoutExtension(trimmed)));
            j.WriteBoolean("tp_in_claude_projects", trimmed.Replace('\\', '/').Contains("/.claude/projects/", StringComparison.OrdinalIgnoreCase));
        }

        // 표시용 작업 폴더 끝 이름 (한글 확인용)
        if (Str(r, "cwd") is string cwd && cwd.Length > 0)
        {
            string last = Path.GetFileName(cwd.TrimEnd('\\', '/'));
            j.WriteString("folder", last.Length > 80 ? last[..80] : last);
        }

        if (r.TryGetProperty("is_interrupt", out var ii) && ii.ValueKind is JsonValueKind.True or JsonValueKind.False)
            j.WriteBoolean("is_interrupt", ii.GetBoolean());
        if (r.TryGetProperty("stop_hook_active", out var sha) && sha.ValueKind is JsonValueKind.True or JsonValueKind.False)
            j.WriteBoolean("stop_hook_active", sha.GetBoolean());
        if (r.TryGetProperty("duration_ms", out var dm) && dm.ValueKind == JsonValueKind.Number && dm.TryGetInt64(out long d))
            j.WriteNumber("duration_ms", d);

        // Stop: 백그라운드 작업 수 (내용 없이 개수·실행 중 개수만)
        if (r.TryGetProperty("background_tasks", out var bt) && bt.ValueKind == JsonValueKind.Array)
        {
            int n = 0, running = 0;
            foreach (var t in bt.EnumerateArray())
            {
                n++;
                if (t.ValueKind == JsonValueKind.Object && Str(t, "status") == "running") running++;
            }
            j.WriteNumber("bg_tasks", n);
            j.WriteNumber("bg_running", running);
        }

        // 도구 실패 여부 후보 (내용은 버리고 표시만)
        if (r.TryGetProperty("tool_response", out var tr) && tr.ValueKind == JsonValueKind.Object)
        {
            if (tr.TryGetProperty("is_error", out var ie) && ie.ValueKind is JsonValueKind.True or JsonValueKind.False)
                j.WriteBoolean("resp_is_error", ie.GetBoolean());
            if (tr.TryGetProperty("interrupted", out var it) && it.ValueKind is JsonValueKind.True or JsonValueKind.False)
                j.WriteBoolean("resp_interrupted", it.GetBoolean());
        }
    }

    // --record: 키 이름과 값의 종류·길이만. 값 자체는 쓰지 않는다.
    static void WriteShape(Utf8JsonWriter j, JsonElement r)
    {
        if (r.ValueKind != JsonValueKind.Object) return;
        j.WriteStartObject("_shape");
        foreach (var p in r.EnumerateObject())
        {
            if (p.Value.ValueKind == JsonValueKind.Object)
            {
                j.WriteStartObject(Clean(p.Name));
                foreach (var c in p.Value.EnumerateObject()) j.WriteString(Clean(c.Name), Kind(c.Value));
                j.WriteEndObject();
            }
            else j.WriteString(Clean(p.Name), Kind(p.Value));
        }
        j.WriteEndObject();
    }

    static string Kind(JsonElement e) => e.ValueKind switch
    {
        JsonValueKind.String => "s" + e.GetString()!.Length,
        JsonValueKind.Number => "n",
        JsonValueKind.True or JsonValueKind.False => "b",
        JsonValueKind.Null => "null",
        JsonValueKind.Array => "a" + e.GetArrayLength(),
        JsonValueKind.Object => "o",
        _ => "?"
    };

    static string? Str(JsonElement r, string key) =>
        r.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;

    static void PutEnum(Utf8JsonWriter j, JsonElement r, string key, string outKey)
    {
        if (Str(r, key) is string s) j.WriteString(outKey, Clean(s));
    }

    // 소문자·_ 만으로 된 32자 이하 낱말 (rate_limit, overloaded 같은 정해진 값)
    static bool IsEnumWord(string s) =>
        s.Length is > 0 and <= 32 && s.All(c => c is (>= 'a' and <= 'z') or '_');

    // 영문·숫자·_·- 만 남기고 64자로 자름 (값이 문장이어도 짧은 꼬리표로만 남음)
    static string Clean(string s)
    {
        var sb = new StringBuilder(Math.Min(s.Length, 64));
        foreach (char c in s)
        {
            if (sb.Length >= 64) break;
            if (c is (>= 'a' and <= 'z') or (>= 'A' and <= 'Z') or (>= '0' and <= '9') or '_' or '-') sb.Append(c);
        }
        return sb.ToString();
    }

    static string Hash(string s) => Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(s)), 0, 8);
}
