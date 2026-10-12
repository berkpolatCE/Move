import AppKit
import MoveCore

@MainActor
extension Chime {
    private static let bells = NSSound(data: wave(bellCount: 3))
    private static let bell = NSSound(data: wave(bellCount: 1))

    static func playBells() {
        play(bells)
    }

    static func playBell() {
        play(bell)
    }

    private static func play(_ sound: NSSound?) {
        sound?.stop()
        sound?.play()
    }
}
