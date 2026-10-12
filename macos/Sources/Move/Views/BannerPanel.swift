import AppKit
import MoveCore
import SwiftUI

@MainActor
final class BannerPanel {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false)
    private var hideTask: Task<Void, Never>?

    init(exercise: Exercise) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let content = NSHostingView(rootView: BannerView(exercise: exercise))
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
    }

    func show() {
        let visible = UserActivity.activeScreen?.visibleFrame ?? .zero
        let size = panel.frame.size
        let target = NSRect(x: visible.maxX - size.width, y: visible.maxY - size.height, width: size.width, height: size.height)

        panel.alphaValue = 0
        panel.setFrame(target.offsetBy(dx: 24, dy: 0), display: false)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self else {
                return
            }

            await NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            }
            close()
        }
    }

    func close() {
        hideTask?.cancel()
        panel.close()
    }
}

private struct BannerView: View {
    let exercise: Exercise

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MoveLogo().frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Time to move").font(.caption).foregroundStyle(.secondary)
                Text(exercise.name)
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                Text(exercise.amountText)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
            }
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 20))
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .frame(width: 348)
        .padding(16)
    }
}
