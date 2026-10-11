namespace Move;

public static class Phrasing
{
    public static string Count(int amount, string unit) => amount == 1 ? $"1 {unit}" : $"{amount} {unit}s";

    public static string Duration(TimeSpan duration) =>
        duration == TimeSpan.FromHours(1) ? "an hour" : Length(duration);

    public static string Length(TimeSpan duration)
    {
        int totalMinutes = (int)Math.Round(duration.TotalMinutes);
        int hours = totalMinutes / 60;
        int minutes = totalMinutes % 60;

        if (hours == 0)
        {
            return Count(minutes, "minute");
        }

        return minutes == 0 ? Count(hours, "hour") : $"{Count(hours, "hour")} {Count(minutes, "minute")}";
    }

    public static string Countdown(TimeSpan remaining)
    {
        if (remaining < TimeSpan.FromMinutes(1))
        {
            return "under a minute";
        }

        int totalMinutes = (int)Math.Ceiling(remaining.TotalMinutes);
        int hours = totalMinutes / 60;
        int minutes = totalMinutes % 60;

        return (hours, minutes) switch
        {
            (0, _) => $"{minutes} min",
            (_, 0) => $"{hours} h",
            _ => $"{hours} h {minutes} min"
        };
    }
}
