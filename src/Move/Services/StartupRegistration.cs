using Microsoft.Win32;

namespace Move.Services;

public static class StartupRegistration
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "Move";

    public static void Apply(bool enabled)
    {
        using RegistryKey key = Registry.CurrentUser.CreateSubKey(RunKeyPath);

        if (enabled && Environment.ProcessPath is { } executablePath)
        {
            key.SetValue(ValueName, $"\"{executablePath}\"");
        }
        else
        {
            key.DeleteValue(ValueName, throwOnMissingValue: false);
        }
    }
}
