using System.Windows;
using System.Windows.Threading;
using Move.Services;

namespace Move;

public partial class App : Application
{
    private const string InstanceMutexName = @"Local\Move.Instance";
    private const string ShowSettingsSignalName = @"Local\Move.ShowSettings";

    private Mutex? instanceMutex;
    private EventWaitHandle? showSettingsSignal;
    private RegisteredWaitHandle? showSettingsWait;
    private ReminderCoordinator? coordinator;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        instanceMutex = new Mutex(true, InstanceMutexName, out bool isFirstInstance);
        showSettingsSignal = new EventWaitHandle(false, EventResetMode.AutoReset, ShowSettingsSignalName);

        if (!isFirstInstance)
        {
            showSettingsSignal.Set();
            Shutdown();
            return;
        }

        DispatcherUnhandledException += OnDispatcherUnhandledException;
        coordinator = new ReminderCoordinator(SettingsStore.Default);

        showSettingsWait = ThreadPool.RegisterWaitForSingleObject(
            showSettingsSignal,
            (_, _) => Dispatcher.InvokeAsync(() => coordinator.OpenSettings()),
            null,
            Timeout.Infinite,
            executeOnlyOnce: false);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        showSettingsWait?.Unregister(null);
        coordinator?.Dispose();
        showSettingsSignal?.Dispose();
        instanceMutex?.Dispose();
        base.OnExit(e);
    }

    private static void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        MessageBox.Show(e.Exception.Message, "Move ran into a problem", MessageBoxButton.OK, MessageBoxImage.Warning);
        e.Handled = true;
    }
}
