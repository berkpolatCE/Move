using Move.Models;
using Move.Services;

namespace Move.Tests;

public class PhrasingTests
{
    [Theory]
    [InlineData(1, "1 minute")]
    [InlineData(45, "45 minutes")]
    [InlineData(60, "an hour")]
    [InlineData(90, "1 hour 30 minutes")]
    [InlineData(120, "2 hours")]
    public void DescribesDurations(int minutes, string expected) =>
        Assert.Equal(expected, Phrasing.Duration(TimeSpan.FromMinutes(minutes)));

    [Theory]
    [InlineData(10, "10 minutes")]
    [InlineData(60, "1 hour")]
    [InlineData(90, "1 hour 30 minutes")]
    [InlineData(120, "2 hours")]
    public void DescribesPickerLengths(int minutes, string expected) =>
        Assert.Equal(expected, Phrasing.Length(TimeSpan.FromMinutes(minutes)));

    [Theory]
    [InlineData(30, "under a minute")]
    [InlineData(60, "1 min")]
    [InlineData(61, "2 min")]
    [InlineData(23 * 60, "23 min")]
    [InlineData(60 * 60, "1 h")]
    [InlineData(65 * 60, "1 h 5 min")]
    public void DescribesCountdowns(int seconds, string expected) =>
        Assert.Equal(expected, Phrasing.Countdown(TimeSpan.FromSeconds(seconds)));

    [Fact]
    public void DescribesExerciseAmounts()
    {
        Assert.Equal("15 reps", new Exercise { Amount = 15, Unit = ExerciseUnit.Reps }.AmountText);
        Assert.Equal("1 rep", new Exercise { Amount = 1, Unit = ExerciseUnit.Reps }.AmountText);
        Assert.Equal("45 seconds", new Exercise { Amount = 45, Unit = ExerciseUnit.Seconds }.AmountText);
    }

    [Theory]
    [InlineData(3, 3.0, 4.0)]
    [InlineData(1, 2.0, 3.0)]
    public void ChimeProducesAValidWaveFile(int bellCount, double minSeconds, double maxSeconds)
    {
        byte[] wave = Chime.CreateWave(bellCount);

        Assert.Equal("RIFF"u8.ToArray(), wave[..4]);
        Assert.Equal("WAVE"u8.ToArray(), wave[8..12]);
        Assert.Equal(wave.Length - 8, BitConverter.ToInt32(wave, 4));
        Assert.InRange(wave.Length / 2.0 / Chime.SampleRate, minSeconds, maxSeconds);
    }
}
