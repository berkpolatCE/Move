using Move.Models;

namespace Move.Services;

public enum ReminderStatus
{
    Counting,
    Due,
    Paused,
    OutsideActiveHours
}

public sealed class ReminderScheduler
{
    public static readonly TimeSpan MaxTickGap = TimeSpan.FromSeconds(30);

    private AppSettings settings;

    public ReminderScheduler(AppSettings settings)
    {
        this.settings = settings;
        Restart();
    }

    public TimeSpan Elapsed { get; private set; }
    public TimeSpan Target { get; private set; }
    public bool IsSnoozed { get; private set; }
    public DateTime? PausedUntil { get; private set; }
    public TimeSpan Remaining => Target > Elapsed ? Target - Elapsed : TimeSpan.Zero;

    public ReminderStatus Tick(DateTime now, TimeSpan sinceLastTick, TimeSpan idle)
    {
        if (PausedUntil is { } until)
        {
            if (now < until)
            {
                return ReminderStatus.Paused;
            }

            Resume();
        }

        if (!settings.IsActiveAt(now))
        {
            Restart();
            return ReminderStatus.OutsideActiveHours;
        }

        bool wasAway = idle >= settings.IdleReset || sinceLastTick >= settings.IdleReset;
        if (settings.TimerMode == TimerMode.ResetWhenIdle && wasAway)
        {
            Restart();
            return ReminderStatus.Counting;
        }

        if (sinceLastTick > TimeSpan.Zero && sinceLastTick <= MaxTickGap)
        {
            Elapsed += sinceLastTick;
        }

        return Elapsed >= Target ? ReminderStatus.Due : ReminderStatus.Counting;
    }

    public void Restart()
    {
        Elapsed = TimeSpan.Zero;
        Target = settings.Interval;
        IsSnoozed = false;
    }

    public void Snooze()
    {
        Elapsed = TimeSpan.Zero;
        Target = settings.Snooze;
        IsSnoozed = true;
    }

    public void Pause(DateTime until) => PausedUntil = until;

    public void Resume()
    {
        PausedUntil = null;
        Restart();
    }

    public void ApplySettings(AppSettings updated)
    {
        settings = updated;
        Target = IsSnoozed ? settings.Snooze : settings.Interval;
    }
}
