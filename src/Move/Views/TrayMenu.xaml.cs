using System.Globalization;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;

namespace Move.Views;

public partial class TrayMenu : ContextMenu
{
    public TrayMenu()
    {
        SetResourceReference(StyleProperty, typeof(ContextMenu));
        InitializeComponent();
        Opened += (_, _) => TakeForeground();
    }

    public event EventHandler? MoveNowRequested;
    public event EventHandler? ResetRequested;
    public event EventHandler<DateTime>? PauseRequested;
    public event EventHandler? ResumeRequested;
    public event EventHandler? SettingsRequested;
    public event EventHandler? ExitRequested;

    public void ShowAtCursor() => IsOpen = true;

    public void ShowStatus(string status, bool isPaused)
    {
        StatusText.Text = status;
        PauseItem.Visibility = isPaused ? Visibility.Collapsed : Visibility.Visible;
        ResumeItem.Visibility = isPaused ? Visibility.Visible : Visibility.Collapsed;
    }

    private void OnMoveNow(object sender, RoutedEventArgs e) => MoveNowRequested?.Invoke(this, EventArgs.Empty);

    private void OnReset(object sender, RoutedEventArgs e) => ResetRequested?.Invoke(this, EventArgs.Empty);

    private void OnPauseForMinutes(object sender, RoutedEventArgs e)
    {
        int minutes = int.Parse((string)((FrameworkElement)sender).Tag, CultureInfo.InvariantCulture);
        PauseRequested?.Invoke(this, DateTime.Now.AddMinutes(minutes));
    }

    private void OnPauseUntilTomorrow(object sender, RoutedEventArgs e) =>
        PauseRequested?.Invoke(this, DateTime.Today.AddDays(1));

    private void OnPauseUntilResumed(object sender, RoutedEventArgs e) =>
        PauseRequested?.Invoke(this, DateTime.MaxValue);

    private void OnResume(object sender, RoutedEventArgs e) => ResumeRequested?.Invoke(this, EventArgs.Empty);

    private void OnSettings(object sender, RoutedEventArgs e) => SettingsRequested?.Invoke(this, EventArgs.Empty);

    private void OnExit(object sender, RoutedEventArgs e) => ExitRequested?.Invoke(this, EventArgs.Empty);

    private void TakeForeground()
    {
        if (PresentationSource.FromVisual(this) is HwndSource source)
        {
            SetForegroundWindow(source.Handle);
        }
    }

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(nint window);
}
