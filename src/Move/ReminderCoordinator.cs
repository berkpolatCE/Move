using System.Windows;
using System.Windows.Threading;
using Move.Models;
using Move.Services;
using Move.Views;

namespace Move;

public sealed class ReminderCoordinator : IDisposable
{
    private readonly SettingsStore store;
    private readonly ReminderScheduler scheduler;
    private readonly ExerciseRotation rotation;
    private readonly TrayIcon tray;
    private readonly DispatcherTimer timer;
    private AppSettings settings;
    private DateTime lastTickUtc;
    private ReminderWindow? reminder;
    private ReminderBanner? banner;
    private SettingsWindow? settingsWindow;
    private (Exercise Exercise, DateTime ShownAt)? lastReminder;

    public ReminderCoordinator(SettingsStore store)
    {
        this.store = store;

        bool isFirstRun = !store.SettingsExist;
        settings = store.LoadSettings();
        if (isFirstRun)
        {
            store.SaveSettings(settings);
        }

        if (settings.StartWithWindows)
        {
            StartupRegistration.Apply(true);
        }

        scheduler = new ReminderScheduler(settings);
        rotation = new ExerciseRotation(settings.Exercises, settings.ShuffleExercises, store.LoadRotation(), Random.Shared);

        tray = new TrayIcon();
        tray.Menu.MoveNowRequested += (_, _) => ShowReminder("Here's your next exercise.");
        tray.Menu.ResetRequested += (_, _) => RunAndRefresh(scheduler.Restart);
        tray.Menu.PauseRequested += (_, until) => Pause(until);
        tray.Menu.ResumeRequested += (_, _) => RunAndRefresh(scheduler.Resume);
        tray.Menu.SettingsRequested += (_, _) => OpenSettings();
        tray.Menu.ExitRequested += (_, _) => Application.Current.Shutdown();

        lastTickUtc = DateTime.UtcNow;
        timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        timer.Tick += (_, _) => OnTick();
        timer.Start();
        UpdateTray(ReminderStatus.Counting);

        if (isFirstRun)
        {
            OpenSettings(isFirstRun: true);
        }
    }

    public void OpenSettings() => OpenSettings(isFirstRun: false);

    public void Dispose()
    {
        timer.Stop();
        tray.Dispose();
    }

    private void OnTick()
    {
        DateTime nowUtc = DateTime.UtcNow;
        TimeSpan sinceLastTick = nowUtc - lastTickUtc;
        lastTickUtc = nowUtc;

        ReminderStatus status = scheduler.Tick(DateTime.Now, sinceLastTick, UserActivity.IdleTime);
        if (status == ReminderStatus.Due && reminder is null)
        {
            status = HandleDueReminder();
        }

        UpdateTray(status);
    }

    private ReminderStatus HandleDueReminder()
    {
        switch (UserActivity.GetPresence())
        {
            case Presence.Away:
                return ReminderStatus.Due;
            case Presence.Fullscreen:
                ShowBanner(rotation.Current);
                Chime.PlayBells();
                MoveToNextExercise();
                return ReminderStatus.Counting;
            default:
                ShowReminder(scheduler.IsSnoozed ? "Snooze is over." : DescribeTimeSinceBreak());
                return ReminderStatus.Due;
        }
    }

    private string DescribeTimeSinceBreak()
    {
        string duration = Phrasing.Duration(settings.Interval);
        return settings.TimerMode == TimerMode.ResetWhenIdle
            ? $"You've been at your computer for {duration}."
            : $"It's been {duration} since your last break.";
    }

    private void ShowReminder(string reason)
    {
        if (reminder is not null)
        {
            reminder.Activate();
            return;
        }

        RecordReminder(rotation.Current);
        reminder = new ReminderWindow(rotation.Current, reason, settings.SnoozeMinutes);
        reminder.Closed += OnReminderClosed;
        reminder.Show();

        if (settings.PlayChimeWithPopup)
        {
            Chime.PlayBells();
        }
    }

    private void OnReminderClosed(object? sender, EventArgs e)
    {
        ReminderResult result = reminder?.Result ?? ReminderResult.Snoozed;
        reminder = null;

        if (result == ReminderResult.Snoozed)
        {
            scheduler.Snooze();
            return;
        }

        MoveToNextExercise();
    }

    private void ShowBanner(Exercise exercise)
    {
        RecordReminder(exercise);
        banner?.Close();
        banner = new ReminderBanner(exercise);
        banner.Closed += (sender, _) =>
        {
            if (ReferenceEquals(sender, banner))
            {
                banner = null;
            }
        };
        banner.Show();
    }

    private void RecordReminder(Exercise exercise) => lastReminder = (exercise, DateTime.Now);

    private void MoveToNextExercise()
    {
        rotation.Advance();
        store.SaveRotation(rotation.State);
        scheduler.Restart();
    }

    private void Pause(DateTime until)
    {
        reminder?.Close();
        scheduler.Pause(until);
        UpdateTray(ReminderStatus.Paused);
    }

    private void RunAndRefresh(Action action)
    {
        action();
        UpdateTray(ReminderStatus.Counting);
    }

    private void OpenSettings(bool isFirstRun)
    {
        if (settingsWindow is not null)
        {
            settingsWindow.Activate();
            return;
        }

        var window = new SettingsWindow(settings, isFirstRun);
        window.Closed += (_, _) =>
        {
            settingsWindow = null;
            if (window.Result is { } updated)
            {
                ApplySettings(updated);
            }
        };

        settingsWindow = window;
        window.Show();
        window.Activate();
    }

    private void ApplySettings(AppSettings updated)
    {
        bool startupChanged = updated.StartWithWindows != settings.StartWithWindows;

        settings = updated;
        scheduler.ApplySettings(settings);
        rotation.Update(settings.Exercises, settings.ShuffleExercises);
        store.SaveRotation(rotation.State);

        if (startupChanged)
        {
            StartupRegistration.Apply(settings.StartWithWindows);
        }

        if (!store.SaveSettings(settings))
        {
            MessageBox.Show(
                "Your changes are active, but they couldn't be saved and will be lost when Move restarts.",
                "Move",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }
    }

    private void UpdateTray(ReminderStatus status)
    {
        tray.ShowStatus(DescribeStatus(status), status == ReminderStatus.Paused);

        if (lastReminder is var (exercise, shownAt))
        {
            tray.Menu.ShowLastReminder(
                $"Last reminder · {Phrasing.Moment(shownAt, DateTime.Now)}",
                $"{exercise.Name} · {exercise.AmountText}");
        }
    }

    private string DescribeStatus(ReminderStatus status) => status switch
    {
        ReminderStatus.Paused => DescribePause(scheduler.PausedUntil),
        ReminderStatus.OutsideActiveHours => $"Off until {settings.ActiveHoursStart.ToShortTimeString()}",
        ReminderStatus.Due => "Time to move!",
        _ when scheduler.IsSnoozed => $"Snoozed, {rotation.Current.Name} in {Phrasing.Countdown(scheduler.Remaining)}",
        _ => $"{rotation.Current.Name} in {Phrasing.Countdown(scheduler.Remaining)}"
    };

    private static string DescribePause(DateTime? until)
    {
        if (until is not { } time || time == DateTime.MaxValue)
        {
            return "Paused";
        }

        if (time == DateTime.Today.AddDays(1))
        {
            return "Paused until tomorrow";
        }

        return $"Paused until {Phrasing.Moment(time, DateTime.Now)}";
    }
}
