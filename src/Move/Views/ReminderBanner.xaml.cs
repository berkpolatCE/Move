using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Move.Models;

namespace Move.Views;

public partial class ReminderBanner : Window
{
    private static readonly TimeSpan VisibleDuration = TimeSpan.FromSeconds(10);
    private static readonly Duration FadeDuration = new(TimeSpan.FromMilliseconds(300));

    private const double EdgeGap = 8;
    private const int ExtendedStyleIndex = -20;
    private const int TransparentStyle = 0x00000020;
    private const int ToolWindowStyle = 0x00000080;
    private const int NoActivateStyle = 0x08000000;
    private const uint MonitorDefaultToNearest = 2;
    private const uint NoSize = 0x0001;
    private const uint NoActivate = 0x0010;
    private static readonly nint TopmostWindow = -1;

    private readonly DispatcherTimer hideTimer = new() { Interval = VisibleDuration };

    public ReminderBanner(Exercise exercise)
    {
        InitializeComponent();

        NameText.Text = exercise.Name;
        AmountText.Text = exercise.AmountText;

        hideTimer.Tick += (_, _) => FadeOut();
        SourceInitialized += (_, _) => MakeClickThrough();
        Loaded += (_, _) => Appear();
        Closed += (_, _) => hideTimer.Stop();
    }

    private void Appear()
    {
        PlaceInCornerOfActiveScreen();
        Root.BeginAnimation(OpacityProperty, new DoubleAnimation(0, 1, FadeDuration));
        RootOffset.BeginAnimation(
            TranslateTransform.XProperty,
            new DoubleAnimation(24, 0, new Duration(TimeSpan.FromMilliseconds(350)))
            {
                EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut }
            });
        hideTimer.Start();
    }

    private void FadeOut()
    {
        hideTimer.Stop();
        var fade = new DoubleAnimation(1, 0, FadeDuration);
        fade.Completed += (_, _) => Close();
        Root.BeginAnimation(OpacityProperty, fade);
    }

    private void MakeClickThrough()
    {
        nint handle = new WindowInteropHelper(this).Handle;
        int style = GetWindowLong(handle, ExtendedStyleIndex);
        SetWindowLong(handle, ExtendedStyleIndex, style | TransparentStyle | ToolWindowStyle | NoActivateStyle);
    }

    private void PlaceInCornerOfActiveScreen()
    {
        nint monitor = MonitorFromWindow(GetForegroundWindow(), MonitorDefaultToNearest);
        var info = new MonitorInfo { Size = (uint)Marshal.SizeOf<MonitorInfo>() };
        if (!GetMonitorInfo(monitor, ref info) || GetDpiForMonitor(monitor, 0, out uint dpi, out _) != 0)
        {
            return;
        }

        double scale = dpi / 96.0;
        int width = (int)Math.Ceiling(ActualWidth * scale);
        int height = (int)Math.Ceiling(ActualHeight * scale);
        int gap = (int)Math.Round(EdgeGap * scale);
        int left = info.WorkArea.Right - width - gap;
        int top = info.WorkArea.Bottom - height - gap;

        SetWindowPos(new WindowInteropHelper(this).Handle, TopmostWindow, left, top, 0, 0, NoSize | NoActivate);
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
    private static extern nint GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern nint MonitorFromWindow(nint window, uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool GetMonitorInfo(nint monitor, ref MonitorInfo info);

    [DllImport("shcore.dll")]
    private static extern int GetDpiForMonitor(nint monitor, int dpiType, out uint dpiX, out uint dpiY);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")]
    private static extern int GetWindowLong(nint window, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")]
    private static extern int SetWindowLong(nint window, int index, int value);

    [DllImport("user32.dll")]
    private static extern bool SetWindowPos(nint window, nint insertAfter, int x, int y, int width, int height, uint flags);
}
