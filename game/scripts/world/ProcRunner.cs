using Godot;
using System;
using System.Diagnostics;
using System.Text;
using System.Threading.Tasks;

/// <summary>
/// 게임 안 한 줄 명령 (로드맵 ⑤) 의 프로세스 실행기 — GDScript 의 OS.execute 는 작업 폴더를 못 정하고, 끝날 때까지 막히고, 자식 프로세스를 못 끊음.
/// 셸을 거치지 않음 (인자는 목록, 사용자 글은 stdin 으로). 시간 제한 · 취소 · 출력 상한 넘으면 프로세스 트리째 종료.
/// 끝나면 Done 신호 (메인 스레드). 동시에 1개만.
/// </summary>
public partial class ProcRunner : Node
{
    [Signal]
    public delegate void DoneEventHandler(int code, string stdout, string stderr, bool timedOut, bool canceled, bool tooBig);

    private Process _proc;
    private volatile bool _canceled;

    public bool Running { get; private set; }

    public bool Start(string exe, string[] args, string cwd, string stdin, int timeoutMs, int maxChars)
    {
        if (Running) return false;
        var psi = new ProcessStartInfo
        {
            FileName = exe,
            WorkingDirectory = cwd,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardInputEncoding = new UTF8Encoding(false),
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };
        foreach (var a in args) psi.ArgumentList.Add(a);
        Process p;
        try { p = Process.Start(psi); }
        catch (Exception) { return false; }
        if (p == null) return false;
        _proc = p;
        _canceled = false;
        Running = true;
        Task.Run(() => Pump(p, stdin, timeoutMs, maxChars));
        return true;
    }

    /// <summary>취소: 프로세스 트리째 종료. 끝나면 Done (canceled = true)</summary>
    public void Cancel()
    {
        _canceled = true;
        if (_proc != null) Kill(_proc);
    }

    private static void Kill(Process p)
    {
        try { p.Kill(true); } catch (Exception) { }
    }

    private void Pump(Process p, string stdin, int timeoutMs, int maxChars)
    {
        var sbOut = new StringBuilder();
        var sbErr = new StringBuilder();
        bool tooBig = false;
        var tOut = Task.Run(() => Drain(p, p.StandardOutput, sbOut, maxChars, () => { tooBig = true; Kill(p); }));
        var tErr = Task.Run(() => Drain(p, p.StandardError, sbErr, 4096, null));
        try
        {
            p.StandardInput.Write(stdin);
            p.StandardInput.Close();
        }
        catch (Exception) { }   // 프로세스가 입력을 안 읽고 끝나도 괜찮음
        bool timedOut = false;
        if (!p.WaitForExit(timeoutMs))
        {
            timedOut = true;
            Kill(p);
            p.WaitForExit(3000);
        }
        tOut.Wait(3000);
        tErr.Wait(3000);
        int code = -1;
        try { if (p.HasExited) code = p.ExitCode; } catch (Exception) { }
        p.Dispose();
        try { CallDeferred(nameof(Finish), code, sbOut.ToString(), sbErr.ToString(), timedOut, _canceled, tooBig); }
        catch (Exception) { }   // 게임이 먼저 꺼져 노드가 없어졌으면 알릴 곳이 없음
    }

    /// <summary>상한 넘으면 더 안 읽고 onFull (상한 없는 stderr 는 그냥 버림)</summary>
    private static void Drain(Process p, System.IO.StreamReader r, StringBuilder sb, int max, Action onFull)
    {
        var buf = new char[4096];
        try
        {
            int n;
            while ((n = r.Read(buf, 0, buf.Length)) > 0)
            {
                if (sb.Length + n > max)
                {
                    onFull?.Invoke();
                    if (onFull != null) return;
                    continue;
                }
                sb.Append(buf, 0, n);
            }
        }
        catch (Exception) { }
    }

    private void Finish(int code, string stdout, string stderr, bool timedOut, bool canceled, bool tooBig)
    {
        _proc = null;
        Running = false;
        EmitSignal(SignalName.Done, code, stdout, stderr, timedOut, canceled, tooBig);
    }

    public override void _ExitTree()
    {
        if (Running && _proc != null) Kill(_proc);   // 게임이 먼저 꺼질 때 남지 않게
    }
}
