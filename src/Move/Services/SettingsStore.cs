using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Move.Models;

namespace Move.Services;

public sealed class SettingsStore(string directory)
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    public static SettingsStore Default { get; } = new(
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Move"));

    private string SettingsPath => Path.Combine(directory, "settings.json");
    private string RotationPath => Path.Combine(directory, "rotation.json");

    public bool SettingsExist => File.Exists(SettingsPath);

    public AppSettings LoadSettings() => (Read<AppSettings>(SettingsPath) ?? new AppSettings()).Normalized();

    public bool SaveSettings(AppSettings settings) => Write(SettingsPath, settings);

    public RotationState LoadRotation() => Read<RotationState>(RotationPath) ?? new RotationState();

    public bool SaveRotation(RotationState state) => Write(RotationPath, state);

    private static T? Read<T>(string path) where T : class
    {
        try
        {
            return File.Exists(path) ? JsonSerializer.Deserialize<T>(File.ReadAllText(path), Options) : null;
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException or JsonException)
        {
            return null;
        }
    }

    private bool Write<T>(string path, T value)
    {
        try
        {
            Directory.CreateDirectory(directory);
            string temporaryPath = path + ".tmp";
            File.WriteAllText(temporaryPath, JsonSerializer.Serialize(value, Options));
            File.Move(temporaryPath, path, overwrite: true);
            return true;
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }
}
