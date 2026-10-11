using System.ComponentModel;
using System.Globalization;
using System.Runtime.CompilerServices;
using Move.Models;

namespace Move.Views;

public sealed class ExerciseItem : INotifyPropertyChanged
{
    private string name = "";
    private string amountText = "";
    private ExerciseUnit unit;
    private string tip = "";
    private bool isEditing;
    private int number;
    private bool canMoveUp;
    private bool canMoveDown;
    private bool canRemove;

    public event PropertyChangedEventHandler? PropertyChanged;

    public bool IsNew { get; set; }

    public string Name
    {
        get => name;
        set
        {
            if (Set(ref name, value))
            {
                OnPropertyChanged(nameof(DisplayName));
            }
        }
    }

    public string AmountText
    {
        get => amountText;
        set
        {
            if (Set(ref amountText, value))
            {
                OnPropertyChanged(nameof(Summary));
            }
        }
    }

    public ExerciseUnit Unit
    {
        get => unit;
        set
        {
            if (Set(ref unit, value))
            {
                OnPropertyChanged(nameof(UnitIndex));
                OnPropertyChanged(nameof(Summary));
            }
        }
    }

    public int UnitIndex
    {
        get => (int)Unit;
        set => Unit = (ExerciseUnit)value;
    }

    public string Tip
    {
        get => tip;
        set
        {
            if (Set(ref tip, value))
            {
                OnPropertyChanged(nameof(Summary));
            }
        }
    }

    public bool IsEditing
    {
        get => isEditing;
        set => Set(ref isEditing, value);
    }

    public int Number
    {
        get => number;
        set => Set(ref number, value);
    }

    public bool CanMoveUp
    {
        get => canMoveUp;
        set => Set(ref canMoveUp, value);
    }

    public bool CanMoveDown
    {
        get => canMoveDown;
        set => Set(ref canMoveDown, value);
    }

    public bool CanRemove
    {
        get => canRemove;
        set => Set(ref canRemove, value);
    }

    public string DisplayName => string.IsNullOrWhiteSpace(Name) ? "Untitled exercise" : Name.Trim();

    public string Summary
    {
        get
        {
            string amount = TryGetAmount(out int value)
                ? new Exercise { Amount = value, Unit = Unit }.AmountText
                : "No amount set";

            return string.IsNullOrWhiteSpace(Tip) ? amount : $"{amount}  ·  {Tip.Trim()}";
        }
    }

    public string? Problem
    {
        get
        {
            if (string.IsNullOrWhiteSpace(Name))
            {
                return $"Exercise {Number} needs a name.";
            }

            return TryGetAmount(out _)
                ? null
                : $"{DisplayName} needs an amount between 1 and {Exercise.MaxAmount}.";
        }
    }

    public static ExerciseItem From(Exercise exercise) => new()
    {
        Name = exercise.Name,
        AmountText = exercise.Amount.ToString(CultureInfo.CurrentCulture),
        Unit = exercise.Unit,
        Tip = exercise.Tip
    };

    public Exercise ToExercise()
    {
        TryGetAmount(out int amount);
        return new Exercise { Name = Name.Trim(), Amount = amount, Unit = Unit, Tip = Tip.Trim() };
    }

    private bool TryGetAmount(out int amount) =>
        int.TryParse(AmountText.Trim(), NumberStyles.Integer, CultureInfo.CurrentCulture, out amount)
        && amount is >= 1 and <= Exercise.MaxAmount;

    private bool Set<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return false;
        }

        field = value;
        OnPropertyChanged(propertyName);
        return true;
    }

    private void OnPropertyChanged(string? propertyName) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
