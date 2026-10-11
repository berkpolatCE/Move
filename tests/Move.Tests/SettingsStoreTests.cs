using System.IO;
using Move.Models;
using Move.Services;

namespace Move.Tests;

public sealed class SettingsStoreTests : IDisposable
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "Move.Tests", Guid.NewGuid().ToString("N"));

    [Fact]
    public void RoundTripsSettings()
    {
        var store = new SettingsStore(directory);
        var settings = new AppSettings
        {
            TimerMode = TimerMode.FixedInterval,
            IntervalMinutes = 45,
            ActiveHoursEnabled = true,
            ActiveHoursStart = new TimeOnly(8, 30),
            Exercises = [new Exercise { Name = "Lunges", Amount = 12, Unit = ExerciseUnit.Reps }]
        };

        Assert.True(store.SaveSettings(settings));
        AppSettings loaded = store.LoadSettings();

        Assert.Equal(TimerMode.FixedInterval, loaded.TimerMode);
        Assert.Equal(45, loaded.IntervalMinutes);
        Assert.Equal(new TimeOnly(8, 30), loaded.ActiveHoursStart);
        Assert.Equal("Lunges", Assert.Single(loaded.Exercises).Name);
    }

    [Fact]
    public void FallsBackToDefaultsWhenTheFileIsCorrupt()
    {
        Directory.CreateDirectory(directory);
        File.WriteAllText(Path.Combine(directory, "settings.json"), "{ not json");

        AppSettings loaded = new SettingsStore(directory).LoadSettings();

        Assert.Equal(60, loaded.IntervalMinutes);
        Assert.Equal(Exercise.Defaults().Count, loaded.Exercises.Count);
    }

    [Fact]
    public void NormalizingClampsValuesAndRestoresExercises()
    {
        var settings = new AppSettings
        {
            IntervalMinutes = 0,
            SnoozeMinutes = 10_000,
            Exercises = [new Exercise { Name = "  ", Amount = 5 }]
        }.Normalized();

        Assert.Equal(AppSettings.MinMinutes, settings.IntervalMinutes);
        Assert.Equal(AppSettings.MaxMinutes, settings.SnoozeMinutes);
        Assert.Equal(Exercise.Defaults().Count, settings.Exercises.Count);
    }

    public void Dispose()
    {
        if (Directory.Exists(directory))
        {
            Directory.Delete(directory, recursive: true);
        }
    }
}
