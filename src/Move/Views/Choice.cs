using System.Windows.Controls;

namespace Move.Views;

public sealed record Choice<T>(T Value, string Label);

public static class Choices
{
    public static IReadOnlyList<Choice<int>> Minutes(IEnumerable<int> presets, int current) =>
        presets.Append(current)
            .Distinct()
            .Order()
            .Select(minutes => new Choice<int>(minutes, Phrasing.Length(TimeSpan.FromMinutes(minutes))))
            .ToList();

    public static IReadOnlyList<Choice<TimeOnly>> HalfHours(TimeOnly current) =>
        Enumerable.Range(0, 48)
            .Select(slot => new TimeOnly(slot / 2, slot % 2 * 30))
            .Append(current)
            .Distinct()
            .Order()
            .Select(time => new Choice<TimeOnly>(time, time.ToShortTimeString()))
            .ToList();

    public static void Show<T>(ComboBox picker, IReadOnlyList<Choice<T>> choices, T selected)
    {
        picker.ItemsSource = choices;
        picker.SelectedItem = choices.First(choice => EqualityComparer<T>.Default.Equals(choice.Value, selected));
    }

    public static T Selected<T>(ComboBox picker) => ((Choice<T>)picker.SelectedItem).Value;
}
