using Move.Models;
using Move.Services;

namespace Move.Tests;

public class ReminderSchedulerTests
{
    private static readonly DateTime Noon = new(2026, 10, 12, 12, 0, 0);
    private static readonly TimeSpan Second = TimeSpan.FromSeconds(1);

    [Fact]
    public void BecomesDueAfterTheInterval()
    {
        var scheduler = new ReminderScheduler(new AppSettings { IntervalMinutes = 60 });

        Assert.Equal(ReminderStatus.Counting, Run(scheduler, TimeSpan.FromMinutes(59)));
        Assert.Equal(ReminderStatus.Due, Run(scheduler, TimeSpan.FromMinutes(1)));
    }

    [Fact]
    public void ResetWhenIdleRestartsAfterSteppingAway()
    {
        var scheduler = new ReminderScheduler(new AppSettings { TimerMode = TimerMode.ResetWhenIdle, IdleResetMinutes = 10 });
        Run(scheduler, TimeSpan.FromMinutes(50));

        scheduler.Tick(Noon, Second, TimeSpan.FromMinutes(10));

        Assert.Equal(TimeSpan.Zero, scheduler.Elapsed);
    }

    [Fact]
    public void ResetWhenIdleKeepsCountingThroughShortBreaksInInput()
    {
        var scheduler = new ReminderScheduler(new AppSettings { TimerMode = TimerMode.ResetWhenIdle, IdleResetMinutes = 10 });

        Run(scheduler, TimeSpan.FromMinutes(30), idle: TimeSpan.FromMinutes(9));

        Assert.Equal(TimeSpan.FromMinutes(30), scheduler.Elapsed);
    }

    [Fact]
    public void FixedIntervalIgnoresIdleTime()
    {
        var scheduler = new ReminderScheduler(new AppSettings { TimerMode = TimerMode.FixedInterval, IntervalMinutes = 60 });

        ReminderStatus status = Run(scheduler, TimeSpan.FromMinutes(60), idle: TimeSpan.FromHours(2));

        Assert.Equal(ReminderStatus.Due, status);
    }

    [Fact]
    public void FixedIntervalDoesNotCountTimeAsleep()
    {
        var scheduler = new ReminderScheduler(new AppSettings { TimerMode = TimerMode.FixedInterval });
        Run(scheduler, TimeSpan.FromMinutes(10));

        ReminderStatus status = scheduler.Tick(Noon.AddHours(3), TimeSpan.FromHours(3), TimeSpan.Zero);

        Assert.Equal(ReminderStatus.Counting, status);
        Assert.Equal(TimeSpan.FromMinutes(10), scheduler.Elapsed);
    }

    [Fact]
    public void ResetWhenIdleRestartsAfterLongSleep()
    {
        var scheduler = new ReminderScheduler(new AppSettings { TimerMode = TimerMode.ResetWhenIdle, IdleResetMinutes = 10 });
        Run(scheduler, TimeSpan.FromMinutes(30));

        scheduler.Tick(Noon.AddMinutes(20), TimeSpan.FromMinutes(20), TimeSpan.Zero);

        Assert.Equal(TimeSpan.Zero, scheduler.Elapsed);
    }

    [Fact]
    public void SnoozeWaitsForTheSnoozeLength()
    {
        var scheduler = new ReminderScheduler(new AppSettings { IntervalMinutes = 60, SnoozeMinutes = 10 });
        Run(scheduler, TimeSpan.FromMinutes(60));

        scheduler.Snooze();

        Assert.True(scheduler.IsSnoozed);
        Assert.Equal(ReminderStatus.Counting, Run(scheduler, TimeSpan.FromMinutes(9)));
        Assert.Equal(ReminderStatus.Due, Run(scheduler, TimeSpan.FromMinutes(1)));
    }

    [Fact]
    public void RestartClearsSnooze()
    {
        var scheduler = new ReminderScheduler(new AppSettings { IntervalMinutes = 60, SnoozeMinutes = 10 });
        scheduler.Snooze();

        scheduler.Restart();

        Assert.False(scheduler.IsSnoozed);
        Assert.Equal(TimeSpan.FromMinutes(60), scheduler.Target);
    }

    [Fact]
    public void PauseHoldsUntilItEndsAndThenStartsFresh()
    {
        var scheduler = new ReminderScheduler(new AppSettings { IntervalMinutes = 60 });
        Run(scheduler, TimeSpan.FromMinutes(45));
        scheduler.Pause(Noon.AddHours(1));

        Assert.Equal(ReminderStatus.Paused, scheduler.Tick(Noon.AddMinutes(59), Second, TimeSpan.Zero));
        Assert.Equal(ReminderStatus.Counting, scheduler.Tick(Noon.AddHours(1), Second, TimeSpan.Zero));
        Assert.Null(scheduler.PausedUntil);
        Assert.Equal(Second, scheduler.Elapsed);
    }

    [Theory]
    [InlineData(8, false)]
    [InlineData(9, true)]
    [InlineData(17, true)]
    [InlineData(18, false)]
    public void ActiveHoursLimitWhenRemindersRun(int hour, bool expectedActive)
    {
        var settings = new AppSettings
        {
            ActiveHoursEnabled = true,
            ActiveHoursStart = new TimeOnly(9, 0),
            ActiveHoursEnd = new TimeOnly(18, 0)
        };
        var scheduler = new ReminderScheduler(settings);

        ReminderStatus status = scheduler.Tick(new DateTime(2026, 10, 12, hour, 30, 0), Second, TimeSpan.Zero);

        Assert.Equal(expectedActive ? ReminderStatus.Counting : ReminderStatus.OutsideActiveHours, status);
    }

    [Theory]
    [InlineData(23, true)]
    [InlineData(3, true)]
    [InlineData(12, false)]
    public void ActiveHoursCanSpanMidnight(int hour, bool expectedActive)
    {
        var settings = new AppSettings
        {
            ActiveHoursEnabled = true,
            ActiveHoursStart = new TimeOnly(22, 0),
            ActiveHoursEnd = new TimeOnly(6, 0)
        };

        Assert.Equal(expectedActive, settings.IsActiveAt(new DateTime(2026, 10, 12, hour, 0, 0)));
    }

    [Fact]
    public void ApplyingSettingsUpdatesTheCurrentCountdown()
    {
        var scheduler = new ReminderScheduler(new AppSettings { IntervalMinutes = 60 });
        Run(scheduler, TimeSpan.FromMinutes(20));

        scheduler.ApplySettings(new AppSettings { IntervalMinutes = 30 });

        Assert.Equal(TimeSpan.FromMinutes(10), scheduler.Remaining);
    }

    private static ReminderStatus Run(ReminderScheduler scheduler, TimeSpan duration, TimeSpan idle = default)
    {
        DateTime now = Noon;
        ReminderStatus status = ReminderStatus.Counting;

        for (TimeSpan passed = TimeSpan.Zero; passed < duration; passed += Second)
        {
            now += Second;
            status = scheduler.Tick(now, Second, idle);
        }

        return status;
    }
}
