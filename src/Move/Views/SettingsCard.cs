using System.Collections;
using System.Windows;
using System.Windows.Controls;

namespace Move.Views;

public sealed class SettingsCard : ContentControl
{
    public static readonly DependencyProperty GlyphProperty =
        DependencyProperty.Register(nameof(Glyph), typeof(string), typeof(SettingsCard));

    public static readonly DependencyProperty HeaderProperty =
        DependencyProperty.Register(nameof(Header), typeof(string), typeof(SettingsCard));

    public static readonly DependencyProperty DescriptionProperty =
        DependencyProperty.Register(nameof(Description), typeof(string), typeof(SettingsCard));

    public static readonly DependencyProperty DetailsProperty =
        DependencyProperty.Register(nameof(Details), typeof(object), typeof(SettingsCard), new PropertyMetadata(null, OnDetailsChanged));

    public string? Glyph
    {
        get => (string?)GetValue(GlyphProperty);
        set => SetValue(GlyphProperty, value);
    }

    public string? Header
    {
        get => (string?)GetValue(HeaderProperty);
        set => SetValue(HeaderProperty, value);
    }

    public string? Description
    {
        get => (string?)GetValue(DescriptionProperty);
        set => SetValue(DescriptionProperty, value);
    }

    public object? Details
    {
        get => GetValue(DetailsProperty);
        set => SetValue(DetailsProperty, value);
    }

    protected override IEnumerator LogicalChildren
    {
        get
        {
            var children = new List<object>();
            IEnumerator? inherited = base.LogicalChildren;
            while (inherited?.MoveNext() == true)
            {
                children.Add(inherited.Current);
            }

            if (Details is not null)
            {
                children.Add(Details);
            }

            return children.GetEnumerator();
        }
    }

    private static void OnDetailsChanged(DependencyObject owner, DependencyPropertyChangedEventArgs e)
    {
        var card = (SettingsCard)owner;

        if (e.OldValue is not null)
        {
            card.RemoveLogicalChild(e.OldValue);
        }

        if (e.NewValue is not null)
        {
            card.AddLogicalChild(e.NewValue);
        }
    }
}
