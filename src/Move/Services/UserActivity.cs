using System.Runtime.InteropServices;
using System.Text;

namespace Move.Services;

public enum Presence
{
    Available,
    Fullscreen,
    Away
}

public static class UserActivity
{
    private const uint MonitorDefaultToNearest = 2;

    private static readonly string[] DesktopWindowClasses = ["Progman", "WorkerW"];

    public static TimeSpan IdleTime
    {
        get
        {
            var info = new LastInputInfo { Size = (uint)Marshal.SizeOf<LastInputInfo>() };
            if (!GetLastInputInfo(ref info))
            {
                return TimeSpan.Zero;
            }

            uint idleMilliseconds = unchecked((uint)Environment.TickCount - info.Time);
            return TimeSpan.FromMilliseconds(idleMilliseconds);
        }
    }

    public static Presence GetPresence()
    {
        if (SHQueryUserNotificationState(out NotificationState state) == 0)
        {
            switch (state)
            {
                case NotificationState.NotPresent:
                    return Presence.Away;
                case NotificationState.Busy:
                case NotificationState.RunningDirect3DFullScreen:
                case NotificationState.PresentationMode:
                    return Presence.Fullscreen;
            }
        }

        return IsForegroundWindowFullscreen() ? Presence.Fullscreen : Presence.Available;
    }

    private static bool IsForegroundWindowFullscreen()
    {
        nint window = GetForegroundWindow();
        if (window == 0 || window == GetShellWindow() || IsZoomed(window) || IsDesktopWindow(window))
        {
            return false;
        }

        if (!GetWindowRect(window, out Rect windowBounds))
        {
            return false;
        }

        var monitorInfo = new MonitorInfo { Size = (uint)Marshal.SizeOf<MonitorInfo>() };
        if (!GetMonitorInfo(MonitorFromWindow(window, MonitorDefaultToNearest), ref monitorInfo))
        {
            return false;
        }

        Rect screen = monitorInfo.Monitor;
        return windowBounds.Left <= screen.Left
            && windowBounds.Top <= screen.Top
            && windowBounds.Right >= screen.Right
            && windowBounds.Bottom >= screen.Bottom;
    }

    private static bool IsDesktopWindow(nint window)
    {
        var className = new StringBuilder(64);
        return GetClassName(window, className, className.Capacity) > 0
            && DesktopWindowClasses.Contains(className.ToString());
    }

    private enum NotificationState
    {
        NotPresent = 1,
        Busy = 2,
        RunningDirect3DFullScreen = 3,
        PresentationMode = 4,
        AcceptsNotifications = 5,
        QuietTime = 6,
        App = 7
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct LastInputInfo
    {
        public uint Size;
        public uint Time;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Rect
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MonitorInfo
    {
        public uint Size;
        public Rect Monitor;
        public Rect WorkArea;
        public uint Flags;
    }

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LastInputInfo info);

    [DllImport("shell32.dll")]
    private static extern int SHQueryUserNotificationState(out NotificationState state);

    [DllImport("user32.dll")]
    private static extern nint GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern nint GetShellWindow();

    [DllImport("user32.dll")]
    private static extern bool IsZoomed(nint window);

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(nint window, out Rect rect);

    [DllImport("user32.dll")]
    private static extern nint MonitorFromWindow(nint window, uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool GetMonitorInfo(nint monitor, ref MonitorInfo info);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetClassName(nint window, StringBuilder className, int maxCount);
}
