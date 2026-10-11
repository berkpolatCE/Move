using System.Drawing;
using System.Windows.Forms;

namespace Move.Views;

public sealed class TrayIcon : IDisposable
{
    private const int MaxTooltipLength = 127;

    private readonly NotifyIcon notifyIcon;

    public TrayIcon()
    {
        Menu = new TrayMenu();
        notifyIcon = new NotifyIcon
        {
            Icon = LoadIcon(),
            Text = "Move",
            Visible = true
        };
        notifyIcon.MouseUp += OnMouseUp;
    }

    public TrayMenu Menu { get; }

    public void ShowStatus(string status, bool isPaused)
    {
        Menu.ShowStatus(status, isPaused);

        string tooltip = $"Move · {status}";
        notifyIcon.Text = tooltip.Length > MaxTooltipLength ? tooltip[..MaxTooltipLength] : tooltip;
    }

    public void Dispose()
    {
        Menu.IsOpen = false;
        notifyIcon.Visible = false;
        notifyIcon.Icon?.Dispose();
        notifyIcon.Dispose();
    }

    private void OnMouseUp(object? sender, MouseEventArgs e)
    {
        if (e.Button is MouseButtons.Left or MouseButtons.Right)
        {
            Menu.ShowAtCursor();
        }
    }

    private static Icon LoadIcon()
    {
        int size = SystemInformation.SmallIconSize.Width;
        return Environment.ProcessPath is { } path && Icon.ExtractIcon(path, 0, size) is { } icon
            ? icon
            : (Icon)SystemIcons.Application.Clone();
    }
}
