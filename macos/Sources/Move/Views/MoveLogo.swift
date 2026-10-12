import AppKit
import SwiftUI

struct MoveLogo: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            context.scaleBy(x: scale, y: scale)
            context.fill(
                Path(roundedRect: CGRect(x: 3, y: 3, width: 94, height: 94), cornerRadius: 20.7),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.176, green: 0.831, blue: 0.749), Color(red: 0.059, green: 0.463, blue: 0.431)]),
                    startPoint: CGPoint(x: 3, y: 3),
                    endPoint: CGPoint(x: 97, y: 97)))
            context.stroke(Self.limbs(), with: .color(.white), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
            context.fill(Self.head(), with: .color(.white))
        }
    }

    nonisolated static func limbs() -> Path {
        Path { path in
            path.move(to: CGPoint(x: 50, y: 40))
            path.addLine(to: CGPoint(x: 50, y: 60))
            for end in [CGPoint(x: 27, y: 20), CGPoint(x: 73, y: 20)] {
                path.move(to: CGPoint(x: 50, y: 43))
                path.addLine(to: end)
            }
            for end in [CGPoint(x: 31, y: 82), CGPoint(x: 69, y: 82)] {
                path.move(to: CGPoint(x: 50, y: 60))
                path.addLine(to: end)
            }
        }
    }

    nonisolated static func head() -> Path {
        Path(ellipseIn: CGRect(x: 41.5, y: 18, width: 17, height: 17))
    }

    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }

            let scale = 18.0 / 76
            context.translateBy(x: 9 - 50 * scale, y: 9 - 50 * scale)
            context.scaleBy(x: scale, y: scale)
            context.addPath(limbs().cgPath)
            context.setLineWidth(8.5)
            context.setLineCap(.round)
            context.strokePath()
            context.addPath(head().cgPath)
            context.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }
}
