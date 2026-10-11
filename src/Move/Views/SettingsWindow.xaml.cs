using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Threading;
using Move.Models;
using Move.Services;

namespace Move.Views;

public partial class SettingsWindow : Window
{
    private static readonly int[] IntervalPresets = [15, 20, 30, 45, 60, 90, 120];
    private static readonly int[] IdleResetPresets = [2, 5, 10, 15, 20, 30];
    private static readonly int[] SnoozePresets = [5, 10, 15, 20, 30];

    private readonly ObservableCollection<ExerciseItem> exercises;

    public SettingsWindow(AppSettings settings, bool isFirstRun)
    {
        InitializeComponent();

        WelcomePanel.Visibility = isFirstRun ? Visibility.Visible : Visibility.Collapsed;

        Choices.Show(IntervalPicker, Choices.Minutes(IntervalPresets, settings.IntervalMinutes), settings.IntervalMinutes);
        Choices.Show(IdleResetPicker, Choices.Minutes(IdleResetPresets, settings.IdleResetMinutes), settings.IdleResetMinutes);
        Choices.Show(SnoozePicker, Choices.Minutes(SnoozePresets, settings.SnoozeMinutes), settings.SnoozeMinutes);
        Choices.Show(ActiveFromPicker, Choices.HalfHours(settings.ActiveHoursStart), settings.ActiveHoursStart);
        Choices.Show(ActiveToPicker, Choices.HalfHours(settings.ActiveHoursEnd), settings.ActiveHoursEnd);

        ResetWhenIdleOption.IsChecked = settings.TimerMode == TimerMode.ResetWhenIdle;
        FixedIntervalOption.IsChecked = settings.TimerMode == TimerMode.FixedInterval;
        ActiveHoursToggle.IsChecked = settings.ActiveHoursEnabled;
        ShuffleToggle.IsChecked = settings.ShuffleExercises;
        ChimeToggle.IsChecked = settings.PlayChimeWithPopup;
        StartWithWindowsToggle.IsChecked = settings.StartWithWindows;

        exercises = new ObservableCollection<ExerciseItem>(settings.Exercises.Select(ExerciseItem.From));
        exercises.CollectionChanged += (_, _) => RefreshPositions();
        RefreshPositions();
        ExerciseList.ItemsSource = exercises;
    }

    public AppSettings? Result { get; private set; }

    private void OnSave(object sender, RoutedEventArgs e)
    {
        if (exercises.FirstOrDefault(item => item.Problem is not null) is { } invalid)
        {
            Expand(invalid);
            ErrorText.Text = invalid.Problem;
            return;
        }

        Result = new AppSettings
        {
            TimerMode = FixedIntervalOption.IsChecked == true ? TimerMode.FixedInterval : TimerMode.ResetWhenIdle,
            IntervalMinutes = Choices.Selected<int>(IntervalPicker),
            IdleResetMinutes = Choices.Selected<int>(IdleResetPicker),
            SnoozeMinutes = Choices.Selected<int>(SnoozePicker),
            ActiveHoursEnabled = ActiveHoursToggle.IsChecked == true,
            ActiveHoursStart = Choices.Selected<TimeOnly>(ActiveFromPicker),
            ActiveHoursEnd = Choices.Selected<TimeOnly>(ActiveToPicker),
            ShuffleExercises = ShuffleToggle.IsChecked == true,
            PlayChimeWithPopup = ChimeToggle.IsChecked == true,
            StartWithWindows = StartWithWindowsToggle.IsChecked == true,
            Exercises = exercises.Select(item => item.ToExercise()).ToList()
        }.Normalized();

        Close();
    }

    private void OnCancel(object sender, RoutedEventArgs e) => Close();

    private void OnPreviewChime(object sender, RoutedEventArgs e) => Chime.PlayBells();

    private void OnAddExercise(object sender, RoutedEventArgs e)
    {
        var item = new ExerciseItem { Name = "New exercise", AmountText = "10", Unit = ExerciseUnit.Reps, IsNew = true };
        exercises.Add(item);
        Expand(item);
    }

    private void OnExerciseExpanded(object sender, RoutedEventArgs e)
    {
        if (ItemOf(sender) is { } item)
        {
            Expand(item);
        }
    }

    private void OnExerciseEditorVisibleChanged(object sender, DependencyPropertyChangedEventArgs e)
    {
        if (e.NewValue is not true || sender is not FrameworkElement editor || ItemOf(editor) is not { } item)
        {
            return;
        }

        Dispatcher.InvokeAsync(() =>
        {
            editor.BringIntoView();

            if (item.IsNew && editor.FindName("NameBox") is TextBox nameBox)
            {
                item.IsNew = false;
                nameBox.Focus();
                nameBox.SelectAll();
            }
        }, DispatcherPriority.Input);
    }

    private void OnMoveExerciseUp(object sender, RoutedEventArgs e) => MoveExercise(sender, -1);

    private void OnMoveExerciseDown(object sender, RoutedEventArgs e) => MoveExercise(sender, 1);

    private void OnRemoveExercise(object sender, RoutedEventArgs e)
    {
        if (ItemOf(sender) is { } item && exercises.Count > 1)
        {
            exercises.Remove(item);
        }
    }

    private void MoveExercise(object sender, int offset)
    {
        if (ItemOf(sender) is not { } item)
        {
            return;
        }

        int index = exercises.IndexOf(item);
        int target = index + offset;
        if (target >= 0 && target < exercises.Count)
        {
            exercises.Move(index, target);
        }
    }

    private void Expand(ExerciseItem item)
    {
        foreach (ExerciseItem other in exercises)
        {
            other.IsEditing = ReferenceEquals(other, item);
        }
    }

    private void RefreshPositions()
    {
        for (int index = 0; index < exercises.Count; index++)
        {
            ExerciseItem item = exercises[index];
            item.Number = index + 1;
            item.CanMoveUp = index > 0;
            item.CanMoveDown = index < exercises.Count - 1;
            item.CanRemove = exercises.Count > 1;
        }
    }

    private static ExerciseItem? ItemOf(object element) => (element as FrameworkElement)?.DataContext as ExerciseItem;
}
