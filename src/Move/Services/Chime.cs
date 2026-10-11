using System.IO;
using System.Media;

namespace Move.Services;

public static class Chime
{
    public const int SampleRate = 44100;

    private const double StrikeSpacingSeconds = 0.45;
    private const double RingSeconds = 2.6;
    private const double FadeOutSeconds = 0.15;
    private const double AttackSeconds = 0.004;
    private const double PeakLevel = 0.6;

    private static readonly double[] BellNotes = [783.99, 1046.50, 1318.51];
    private static readonly double[] PartialRatios = [1.0, 2.0, 3.0, 4.2, 5.4];
    private static readonly double[] PartialLevels = [1.0, 0.5, 0.25, 0.12, 0.06];

    private static readonly Lazy<SoundPlayer> BellsPlayer = new(() => CreatePlayer(BellNotes.Length));
    private static readonly Lazy<SoundPlayer> BellPlayer = new(() => CreatePlayer(1));

    public static void PlayBells() => BellsPlayer.Value.Play();

    public static void PlayBell() => BellPlayer.Value.Play();

    public static byte[] CreateWave(int bellCount)
    {
        double[] samples = MixBells(BellNotes[^Math.Clamp(bellCount, 1, BellNotes.Length)..]);
        double peak = samples.Max(sample => Math.Abs(sample));
        double scale = peak > 0 ? PeakLevel / peak * short.MaxValue : 0;
        int dataBytes = samples.Length * sizeof(short);

        using var stream = new MemoryStream(44 + dataBytes);
        using var writer = new BinaryWriter(stream);
        writer.Write("RIFF"u8);
        writer.Write(36 + dataBytes);
        writer.Write("WAVE"u8);
        writer.Write("fmt "u8);
        writer.Write(16);
        writer.Write((short)1);
        writer.Write((short)1);
        writer.Write(SampleRate);
        writer.Write(SampleRate * sizeof(short));
        writer.Write((short)sizeof(short));
        writer.Write((short)16);
        writer.Write("data"u8);
        writer.Write(dataBytes);

        foreach (double sample in samples)
        {
            writer.Write((short)Math.Round(sample * scale));
        }

        writer.Flush();
        return stream.ToArray();
    }

    private static double[] MixBells(double[] notes)
    {
        int ringSamples = (int)(RingSeconds * SampleRate);
        int spacingSamples = (int)(StrikeSpacingSeconds * SampleRate);
        int fadeSamples = (int)(FadeOutSeconds * SampleRate);
        var mix = new double[spacingSamples * (notes.Length - 1) + ringSamples];

        for (int strike = 0; strike < notes.Length; strike++)
        {
            int offset = strike * spacingSamples;

            for (int i = 0; i < ringSamples; i++)
            {
                double time = (double)i / SampleRate;
                double attack = 1 - Math.Exp(-time / AttackSeconds);
                double fade = Math.Min(1, (double)(ringSamples - i) / fadeSamples);
                double tone = 0;

                for (int partial = 0; partial < PartialRatios.Length; partial++)
                {
                    double decay = Math.Exp(-time * (1.6 + partial * 1.8));
                    tone += PartialLevels[partial] * decay * Math.Sin(2 * Math.PI * notes[strike] * PartialRatios[partial] * time);
                }

                mix[offset + i] += attack * fade * tone;
            }
        }

        return mix;
    }

    private static SoundPlayer CreatePlayer(int bellCount)
    {
        var player = new SoundPlayer(new MemoryStream(CreateWave(bellCount)));
        player.Load();
        return player;
    }
}
