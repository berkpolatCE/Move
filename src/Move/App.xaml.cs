using System.Windows;
using System.Windows.Threading;
using Move.Services;

namespace Move;

public partial class App : Application
{
    private const string InstanceMutexName = @"Local\Move.Instance";
    private const string ShowSettingsSignalName = @"Local\Move.ShowSettings";
    private const string ExitSignalName = @"Local\Move.Exit";
    private const string UninstallArgument = "--uninstall";

    private static readonly TimeSpan ExitTimeout = TimeSpan.FromSeconds(5);

    private Mutex? instanceMutex;
    private EventWaitHandle? showSettingsSignal;
    private EventWaitHandle? exitSignal;
    private RegisteredWaitHandle? showSettingsWait;
    private RegisteredWaitHandle? exitWait;
    private ReminderCoordinator? coordinator;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        if (e.Args.Contains(UninstallArgument, StringComparer.OrdinalIgnoreCase))
        {
            PrepareForUninstall();
            Shutdown();
            return;
        }

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

        exitSignal = new EventWaitHandle(false, EventResetMode.AutoReset, ExitSignalName);
        exitWait = ThreadPool.RegisterWaitForSingleObject(
            exitSignal,
            (_, _) => Dispatcher.InvokeAsync(() => Shutdown()),
            null,
            Timeout.Infinite,
            executeOnlyOnce: true);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        showSettingsWait?.Unregister(null);
        exitWait?.Unregister(null);
        coordinator?.Dispose();
        showSettingsSignal?.Dispose();
        exitSignal?.Dispose();
        instanceMutex?.Dispose();
        base.OnExit(e);
    }

    private static void PrepareForUninstall()
    {
        StartupRegistration.Apply(false);

        if (!EventWaitHandle.TryOpenExisting(ExitSignalName, out EventWaitHandle? runningExitSignal))
        {
            return;
        }

        using (runningExitSignal)
        {
            runningExitSignal.Set();
        }

        if (!Mutex.TryOpenExisting(InstanceMutexName, out Mutex? runningInstance))
        {
            return;
        }

        using (runningInstance)
        {
            try
            {
                runningInstance.WaitOne(ExitTimeout);
            }
            catch (AbandonedMutexException)
            {
            }
        }
    }

    private static void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        MessageBox.Show(e.Exception.Message, "Move ran into a problem", MessageBoxButton.OK, MessageBoxImage.Warning);
        e.Handled = true;
    }
}
