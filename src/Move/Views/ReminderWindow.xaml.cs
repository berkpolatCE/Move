using System.Diagnostics;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using Move.Models;
using Move.Services;

namespace Move.Views;

public partial class ReminderWindow : Window
{
    private const string PlayGlyph = "";
    private const string StopGlyph = "";
    private const string RepeatGlyph = "";

    private readonly TimeSpan countdownLength;
    private readonly Stopwatch countdown = new();
    private readonly DispatcherTimer countdownTicker = new() { Interval = TimeSpan.FromMilliseconds(100) };

    public ReminderWindow(Exercise exercise, string reason, int snoozeMinutes)
    {
        InitializeComponent();

        ReasonText.Text = reason;
        NameText.Text = exercise.Name;
        AmountText.Text = exercise.AmountText;
        TipText.Text = exercise.Tip;
        TipText.Visibility = string.IsNullOrWhiteSpace(exercise.Tip) ? Visibility.Collapsed : Visibility.Visible;
        SnoozeButton.Content = $"Snooze {snoozeMinutes} min";

        countdownLength = TimeSpan.FromSeconds(exercise.Amount);
        if (exercise.Unit == ExerciseUnit.Seconds)
        {
            CountdownPanel.Visibility = Visibility.Visible;
            ResetCountdown();
        }

        countdownTicker.Tick += (_, _) => UpdateCountdown();
        Closed += (_, _) => countdownTicker.Stop();
    }

    public ReminderResult Result { get; private set; } = ReminderResult.Snoozed;

    private void OnDone(object sender, RoutedEventArgs e) => CloseWith(ReminderResult.Done);

    private void OnSnooze(object sender, RoutedEventArgs e) => CloseWith(ReminderResult.Snoozed);

    private void OnSkip(object sender, RoutedEventArgs e) => CloseWith(ReminderResult.Skipped);

    private void OnBackgroundMouseDown(object sender, MouseButtonEventArgs e) => DragMove();

    private void OnCountdownButtonClick(object sender, RoutedEventArgs e)
    {
        if (countdown.IsRunning)
        {
            ResetCountdown();
        }
        else
        {
            StartCountdown();
        }
    }

    private void StartCountdown()
    {
        countdown.Restart();
        countdownTicker.Start();
        CountdownProgress.Visibility = Visibility.Visible;
        ShowCountdownAction(StopGlyph, "Stop");
        UpdateCountdown();
    }

    private void ResetCountdown()
    {
        countdown.Reset();
        countdownTicker.Stop();
        CountdownProgress.Value = 0;
        CountdownProgress.Visibility = Visibility.Hidden;
        RemainingText.Text = FormatClock(countdownLength);
        ShowCountdownAction(PlayGlyph, "Start timer");
    }

    private void UpdateCountdown()
    {
        TimeSpan elapsed = countdown.Elapsed;
        if (elapsed < countdownLength)
        {
            CountdownProgress.Value = elapsed / countdownLength;
            RemainingText.Text = FormatClock(countdownLength - elapsed);
            return;
        }

        countdown.Stop();
        countdownTicker.Stop();
        CountdownProgress.Value = 1;
        RemainingText.Text = "Time's up";
        ShowCountdownAction(RepeatGlyph, "Again");
        Chime.PlayBell();
    }

    private void ShowCountdownAction(string glyph, string label)
    {
        CountdownGlyph.Text = glyph;
        CountdownLabel.Text = label;
    }

    private void CloseWith(ReminderResult result)
    {
        Result = result;
        Close();
    }

    private static string FormatClock(TimeSpan remaining) =>
        TimeSpan.FromSeconds(Math.Ceiling(remaining.TotalSeconds)).ToString(@"m\:ss");
}
