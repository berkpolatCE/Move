import Foundation

public enum Chime {
    public static let sampleRate = 44100

    public static func wave(bellCount: Int) -> Data {
        let notes = [783.99, 1046.50, 1318.51]
        let samples = mix(Array(notes.suffix(bellCount.clamped(to: 1...notes.count))))
        let peak = samples.map(abs).max() ?? 0
        let scale = peak > 0 ? 0.6 / peak * Double(Int16.max) : 0
        let pcm = samples.map { Int16(($0 * scale).rounded(.toNearestOrEven)).littleEndian }
        let dataBytes = pcm.count * MemoryLayout<Int16>.size

        var wave = Data(capacity: 44 + dataBytes)
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { wave.append(contentsOf: $0) }
        }

        wave.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataBytes))
        wave.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * MemoryLayout<Int16>.size))
        append(UInt16(MemoryLayout<Int16>.size))
        append(UInt16(16))
        wave.append(contentsOf: Array("data".utf8))
        append(UInt32(dataBytes))
        pcm.withUnsafeBytes { wave.append(contentsOf: $0) }
        return wave
    }

    private static func mix(_ notes: [Double]) -> [Double] {
        let rate = Double(sampleRate)
        let ringSamples = Int(2.6 * rate)
        let spacingSamples = Int(0.45 * rate)
        let fadeSamples = Int(0.15 * rate)
        let partialRatios = [1.0, 2.0, 3.0, 4.2, 5.4]
        let partialLevels = [1.0, 0.5, 0.25, 0.12, 0.06]
        var mix = [Double](repeating: 0, count: spacingSamples * (notes.count - 1) + ringSamples)

        for (strike, note) in notes.enumerated() {
            let offset = strike * spacingSamples

            for i in 0..<ringSamples {
                let time = Double(i) / rate
                let attack = 1 - exp(-time / 0.004)
                let fade = min(1, Double(ringSamples - i) / Double(fadeSamples))
                var tone = 0.0

                for partial in partialRatios.indices {
                    let decay = exp(-time * (1.6 + Double(partial) * 1.8))
                    tone += partialLevels[partial] * decay * sin(2 * .pi * note * partialRatios[partial] * time)
                }

                mix[offset + i] += attack * fade * tone
            }
        }

        return mix
    }
}
