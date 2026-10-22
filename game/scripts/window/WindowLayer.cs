using Godot;
using System;
using System.Runtime.InteropServices;

/// <summary>
/// 창 모드 ③ "바탕화면 고정" — GDScript로는 못 부르는 Windows 기능(user32.dll)을 C#으로 호출.
/// 켜면: 창을 맨 아래로 보내고, 클릭해도 앞으로 튀어나오지 않게(NOACTIVATE) 함.
/// </summary>
public partial class WindowLayer : Node
{
    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")]
    private static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    private static readonly IntPtr HWND_BOTTOM = new(1);
    private static readonly IntPtr HWND_NOTOPMOST = new(-2);
    private const int GWL_EXSTYLE = -20;
    private const long WS_EX_NOACTIVATE = 0x08000000;
    private const uint SWP_NOSIZE = 0x0001, SWP_NOMOVE = 0x0002, SWP_NOACTIVATE = 0x0010;

    private bool _pinBottom;
    private double _timer;

    private static IntPtr Hwnd =>
        (IntPtr)DisplayServer.WindowGetNativeHandle(DisplayServer.HandleType.WindowHandle);

    public void SetBottom(bool enable)
    {
        if (!OperatingSystem.IsWindows()) return;
        _pinBottom = enable;

        long ex = GetWindowLongPtr(Hwnd, GWL_EXSTYLE).ToInt64();
        ex = enable ? ex | WS_EX_NOACTIVATE : ex & ~WS_EX_NOACTIVATE;
        SetWindowLongPtr(Hwnd, GWL_EXSTYLE, new IntPtr(ex));

        SetWindowPos(Hwnd, enable ? HWND_BOTTOM : HWND_NOTOPMOST, 0, 0, 0, 0,
            SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE);
    }

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "FindWindowW")]
    private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    private static System.Threading.Mutex _single;

    /// <summary>정체성 상수는 identity.gd 한곳에만 둠 → C# 은 그 파일의 상수를 읽어서 씀</summary>
    private static Godot.Collections.Dictionary _identity;
    private static string Id(string key)
    {
        _identity ??= GD.Load<Script>("res://scripts/game/identity.gd").GetScriptConstantMap();
        return (string)_identity[key];
    }

    /// <summary>자동 점검용: C# 이 실제로 쓰는 정체성 값 [뮤텍스, 자동 실행 이름, 앱 ID]</summary>
    public string[] IdentityInUse() => new[] { Id("MUTEX"), RunName, Id("APP_ID") };

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SetCurrentProcessExplicitAppUserModelID(string appId);

    /// <summary>
    /// Windows 알림 · 작업 표시줄이 이 게임을 오버랜드와 다른 앱으로 보게 앱 ID 를 정함 (켤 때 가장 먼저 한 번).
    /// 실제 Windows 알림 ('확실' 세기) 은 M3 에서 이 ID 로 띄움.
    /// </summary>
    public void ApplyAppId()
    {
        if (!OperatingSystem.IsWindows()) return;
        SetCurrentProcessExplicitAppUserModelID(Id("APP_ID"));
    }

    /// <summary>
    /// 배포판에서 이미 게임이 실행 중이면 그 창을 보이게 하고 true (이쪽은 바로 꺼야 함 — 저장 파일을 둘이 같이 쓰지 않게).
    /// 개발 실행(디버그 빌드)은 테스트를 여러 개 띄우므로 검사하지 않음.
    /// </summary>
    public bool AnotherInstanceRunning()
    {
        if (!OperatingSystem.IsWindows() || OS.IsDebugBuild()) return false;
        if (_single != null) return false;   // 이 프로세스가 이미 잡고 있음 (장면 다시 불러오기: 처음부터 다시·확장 켜고 끄기)
        var m = new System.Threading.Mutex(true, Id("MUTEX"), out bool created);
        if (created) { _single = m; return false; }
        m.Dispose();
        IntPtr h = FindWindow(null, (string)ProjectSettings.GetSetting("application/config/name"));
        if (h != IntPtr.Zero)
        {
            ShowWindow(h, 5);   // SW_SHOW (트레이로 숨겨 둔 경우에도 보이게)
            SetForegroundWindow(h);
        }
        return true;
    }

    private const int SW_HIDE = 0, SW_SHOWNOACTIVATE = 4;

    /// <summary>
    /// 창 숨기기/보이기 (트레이·전체 화면 감지용).
    /// Godot의 Window.visible = false 는 메인 창에서 무시되므로 Windows 기능으로 직접 처리.
    /// 보일 때는 포커스를 뺏지 않게(SW_SHOWNOACTIVATE)
    /// </summary>
    public void SetHidden(bool hidden)
    {
        if (!OperatingSystem.IsWindows()) return;
        ShowWindow(Hwnd, hidden ? SW_HIDE : SW_SHOWNOACTIVATE);
        if (!hidden && _pinBottom)
            SetWindowPos(Hwnd, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE);
    }

    [DllImport("shell32.dll")]
    private static extern int SHQueryUserNotificationState(out int state);

    /// <summary>
    /// 다른 프로그램이 전체 화면으로 실행 중인지 (게임·영상·발표 모드)
    /// QUNS_BUSY(2) / QUNS_RUNNING_D3D_FULL_SCREEN(3) / QUNS_PRESENTATION_MODE(4)
    /// </summary>
    public bool IsFullscreenAppRunning()
    {
        if (!OperatingSystem.IsWindows()) return false;
        // 3 = 전용 전체 화면 게임(D3D), 4 = 발표 모드. (2 '바쁨'은 어느 모니터인지 알 수 없어 제외)
        bool busy = SHQueryUserNotificationState(out int state) == 0 && (state == 3 || state == 4);
        return busy || ForegroundCoversMonitor();
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    private struct MONITORINFO { public int cbSize; public RECT rcMonitor, rcWork; public uint dwFlags; }

    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] private static extern IntPtr MonitorFromWindow(IntPtr hWnd, uint flags);
    [DllImport("user32.dll")] private static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO info);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder name, int max);

    /// <summary>
    /// 맨 앞 창이 모니터 전체를 덮는지 (브라우저 동영상 전체 화면 등 — 위의 상태값으로는 안 잡히는 경우)
    /// 최대화 창은 작업 표시줄을 남기므로 제외됨. 바탕화면·작업 표시줄·이 섬 창 자신도 제외
    /// </summary>
    private bool ForegroundCoversMonitor()
    {
        IntPtr fg = GetForegroundWindow();
        if (fg == IntPtr.Zero || fg == Hwnd) return false;
        var cls = new System.Text.StringBuilder(64);
        GetClassName(fg, cls, 64);
        string c = cls.ToString();
        if (c == "Progman" || c == "WorkerW" || c == "Shell_TrayWnd" || c == "Shell_SecondaryTrayWnd") return false;
        if (!GetWindowRect(fg, out RECT r)) return false;
        IntPtr mon = MonitorFromWindow(fg, 2);   // 2 = 가장 가까운 모니터
        if (mon != MonitorFromWindow(Hwnd, 2)) return false;   // 섬과 다른 모니터의 전체 화면은 무시
        var mi = new MONITORINFO { cbSize = Marshal.SizeOf<MONITORINFO>() };
        if (!GetMonitorInfo(mon, ref mi)) return false;
        return r.Left <= mi.rcMonitor.Left && r.Top <= mi.rcMonitor.Top
            && r.Right >= mi.rcMonitor.Right && r.Bottom >= mi.rcMonitor.Bottom;
    }

    /// <summary>확인용: 상태값과 맨 앞 창 정보</summary>
    public string DescribeFullscreen()
    {
        SHQueryUserNotificationState(out int state);
        IntPtr fg = GetForegroundWindow();
        var cls = new System.Text.StringBuilder(64);
        GetClassName(fg, cls, 64);
        GetWindowRect(fg, out RECT r);
        return $"상태값={state} 맨앞창={cls} ({r.Left},{r.Top})-({r.Right},{r.Bottom}) 덮음={ForegroundCoversMonitor()}";
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    /// <summary>마지막 키보드·마우스 입력 후 지난 시간(초) — 자리 비움 감지용</summary>
    public double GetIdleSeconds()
    {
        if (!OperatingSystem.IsWindows()) return 0;
        var info = new LASTINPUTINFO { cbSize = (uint)Marshal.SizeOf<LASTINPUTINFO>() };
        if (!GetLastInputInfo(ref info)) return 0;
        return unchecked((uint)System.Environment.TickCount - info.dwTime) / 1000.0;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SYSTEM_POWER_STATUS
    {
        public byte ACLineStatus, BatteryFlag, BatteryLifePercent, SystemStatusFlag;
        public int BatteryLifeTime, BatteryFullLifeTime;
    }

    [DllImport("kernel32.dll")]
    private static extern bool GetSystemPowerStatus(out SYSTEM_POWER_STATUS status);

    /// <summary>노트북이 배터리로 동작 중인지 (전원 연결 안 됨) — 저전력 모드 자동 전환용</summary>
    public bool IsOnBattery()
    {
        if (!OperatingSystem.IsWindows()) return false;
        if (!GetSystemPowerStatus(out var s)) return false;
        return s.ACLineStatus == 0 && s.BatteryFlag != 128;   // 0 = 전원 없음, 128 = 배터리 없음(데스크톱)
    }

    public override void _Process(double delta)
    {
        if (!_pinBottom) return;
        // 다른 프로그램이 Z순서를 바꿔도 0.5초마다 다시 맨 아래로
        _timer += delta;
        if (_timer < 0.5) return;
        _timer = 0;
        SetWindowPos(Hwnd, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE);
    }

    // ---------------------------------------------------------------- Windows 시작 시 자동 실행
    // 현재 사용자의 시작 프로그램(레지스트리 HKCU\...\Run)에 이 exe 경로를 등록/삭제 (관리자 권한 필요 없음)
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private static string RunName => Id("RUN_NAME");

    /// <summary>exe로 내보낸 게임에서만 사용 (개발 실행은 실행 파일이 Godot 편집기라서 등록하면 안 됨)</summary>
    public bool CanAutoStart() => OperatingSystem.IsWindows() && !OS.HasFeature("editor");

    public bool IsAutoStart()
    {
        if (!OperatingSystem.IsWindows()) return false;
        using var k = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(RunKey);
        return k?.GetValue(RunName) is string;
    }

    public void SetAutoStart(bool enable)
    {
        if (!CanAutoStart() || !OperatingSystem.IsWindows()) return;
        using var k = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(RunKey);
        if (enable) k.SetValue(RunName, $"\"{OS.GetExecutablePath()}\"");
        else k.DeleteValue(RunName, false);
    }

    /// <summary>시작할 때: 자동 실행이 켜져 있는데 exe를 다른 곳으로 옮겼으면 새 경로로 고침</summary>
    public void RefreshAutoStart()
    {
        if (CanAutoStart() && IsAutoStart()) SetAutoStart(true);
    }

    // ------------------------------------------------------------------ 미니 모드 (다른 창에 가려지면 작은 섬)
    [DllImport("user32.dll")] private static extern IntPtr GetWindow(IntPtr hWnd, uint cmd);
    [DllImport("user32.dll")] private static extern IntPtr GetTopWindow(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] private static extern IntPtr WindowFromPoint(POINT p);
    [DllImport("user32.dll")] private static extern IntPtr GetAncestor(IntPtr hWnd, uint flags);
    [DllImport("user32.dll")] private static extern bool SetLayeredWindowAttributes(IntPtr hWnd, uint key, byte alpha, uint flags);
    [DllImport("dwmapi.dll")] private static extern int DwmGetWindowAttribute(IntPtr hWnd, int attr, out RECT rect, int size);
    [DllImport("dwmapi.dll", EntryPoint = "DwmGetWindowAttribute")] private static extern int DwmGetCloaked(IntPtr hWnd, int attr, out int cloaked, int size);

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int X, Y; }

    private const uint GW_HWNDNEXT = 2, GW_HWNDPREV = 3;
    private const long WS_EX_TRANSPARENT = 0x20, WS_EX_LAYERED = 0x80000, WS_EX_TOOLWINDOW = 0x80, WS_EX_TOPMOST = 0x8;
    private static readonly IntPtr HWND_TOP = IntPtr.Zero;
    private static readonly IntPtr HWND_TOPMOST = new(-1);

    [DllImport("user32.dll")] private static extern bool IsWindow(IntPtr hWnd);

    /// <summary>
    /// 섬을 가릴 수 있는 창인지 + 화면 사각형.
    /// 제외: 이 게임 창, 숨김·최소화·가상 데스크톱에 숨은 창, 클릭이 통과되는 오버레이, 작은 도구 창, 바탕화면·작업 표시줄
    /// </summary>
    private static bool Qualifies(IntPtr h, out RECT r)
    {
        r = default;
        if (h == IntPtr.Zero || !IsWindow(h) || !IsWindowVisible(h) || IsIconic(h)) return false;
        GetWindowThreadProcessId(h, out uint pid);
        if (pid == (uint)System.Environment.ProcessId) return false;
        long ex = GetWindowLongPtr(h, GWL_EXSTYLE).ToInt64();
        if ((ex & WS_EX_TRANSPARENT) != 0 || (ex & WS_EX_TOOLWINDOW) != 0) return false;
        if (DwmGetCloaked(h, 14, out int c, 4) == 0 && c != 0) return false;   // 14 = DWMWA_CLOAKED
        var cls = new System.Text.StringBuilder(64);
        GetClassName(h, cls, 64);
        string name = cls.ToString();
        if (name == "Progman" || name == "WorkerW" || name == "Shell_TrayWnd" || name == "Shell_SecondaryTrayWnd") return false;
        if (DwmGetWindowAttribute(h, 9, out r, Marshal.SizeOf<RECT>()) != 0)   // 9 = 보이는 테두리 기준
            GetWindowRect(h, out r);
        return r.Right - r.Left > 40 && r.Bottom - r.Top > 40;
    }

    /// <summary>이 창보다 위(Z 순서)에 있는, 섬을 가릴 수 있는 창들</summary>
    public long[] AboveHandles()
    {
        var list = new System.Collections.Generic.List<long>();
        if (!OperatingSystem.IsWindows()) return list.ToArray();
        IntPtr h = GetWindow(Hwnd, GW_HWNDPREV);
        for (int guard = 0; h != IntPtr.Zero && guard < 600; guard++)
        {
            if (Qualifies(h, out _)) list.Add(h.ToInt64());
            h = GetWindow(h, GW_HWNDPREV);
        }
        return list.ToArray();
    }

    /// <summary>주어진 창들 중 지금 보이는 것의 사각형 [왼, 위, 오른, 아래, ...]</summary>
    public int[] RectsOf(long[] handles)
    {
        var list = new System.Collections.Generic.List<int>();
        if (!OperatingSystem.IsWindows()) return list.ToArray();
        foreach (long v in handles)
            if (Qualifies(new IntPtr(v), out RECT r))
                list.AddRange(new[] { r.Left, r.Top, r.Right, r.Bottom });
        return list.ToArray();
    }

    /// <summary>지금 맨 앞(포커스) 창 — 가릴 수 있는 창이 아니면 0</summary>
    public long ForegroundHandle()
    {
        if (!OperatingSystem.IsWindows()) return 0;
        IntPtr fg = GetForegroundWindow();
        return Qualifies(fg, out _) ? fg.ToInt64() : 0;
    }

    /// <summary>창 전체 클릭 통과 (보이기는 그대로) — 미니 모드에서 뒤의 창을 클릭할 수 있게</summary>
    public void SetClickThrough(bool on)
    {
        if (!OperatingSystem.IsWindows()) return;
        long ex = GetWindowLongPtr(Hwnd, GWL_EXSTYLE).ToInt64();
        ex = on ? ex | WS_EX_TRANSPARENT | WS_EX_LAYERED : ex & ~WS_EX_TRANSPARENT & ~WS_EX_LAYERED;
        SetWindowLongPtr(Hwnd, GWL_EXSTYLE, new IntPtr(ex));
        if (on) SetLayeredWindowAttributes(Hwnd, 0, 255, 0x2);   // LWA_ALPHA 255: 모양은 그대로
    }

    /// <summary>창 전체 투명도 0~1 (클릭 통과를 켠 동안만 — 층 창 기능 사용)</summary>
    public void SetOpacity(float a)
    {
        if (!OperatingSystem.IsWindows()) return;
        SetLayeredWindowAttributes(Hwnd, 0, (byte)Math.Clamp((int)Math.Round(a * 255), 0, 255), 0x2);
    }

    /// <summary>점검용: 화면 좌표의 창이 이 게임 창인지 (클릭 통과 확인)</summary>
    public bool IsMineAt(int x, int y)
    {
        IntPtr h = WindowFromPoint(new POINT { X = x, Y = y });
        return h != IntPtr.Zero && GetAncestor(h, 2) == Hwnd;   // 2 = GA_ROOT
    }

    /// <summary>미니 모드에서 꺼낼 때: 다른 창들 위로 (포커스는 가져옴)</summary>
    public void BringToFront()
    {
        if (!OperatingSystem.IsWindows()) return;
        ShowWindow(Hwnd, SW_SHOWNOACTIVATE);
        SetWindowPos(Hwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE);
        SetForegroundWindow(Hwnd);
    }
}
