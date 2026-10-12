import AppKit
import MoveCore
import SwiftUI

enum ReminderResult {
    case done
    case snoozed
    case skipped
}

@MainActor
final class ReminderPanel {
    private let panel = NSPanel(
        contentRect: .zero,
        styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
        backing: .buffered,
        defer: false)
    private let onClose: (ReminderResult) -> Void

    init(exercise: Exercise, reason: String, snoozeMinutes: Int, onClose: @escaping (ReminderResult) -> Void) {
        self.onClose = onClose

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let content = NSHostingView(
            rootView: ReminderView(exercise: exercise, reason: reason, snoozeMinutes: snoozeMinutes) { [weak self] result in
                self?.finish(result)
            })
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
    }

    func show() {
        let visible = UserActivity.activeScreen?.visibleFrame ?? .zero
        let size = panel.frame.size
        let target = NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height)

        panel.alphaValue = 0
        panel.setFrame(target.offsetBy(dx: 0, dy: -18), display: false)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }
    }

    func bringToFront() {
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        finish(.snoozed)
    }

    private func finish(_ result: ReminderResult) {
        guard panel.isVisible else {
            return
        }

        panel.close()
        onClose(result)
    }
}

private struct ReminderView: View {
    let exercise: Exercise
    let reason: String
    let snoozeMinutes: Int
    let finish: (ReminderResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    MoveLogo().frame(width: 20, height: 20)
                    Text("Time to move").font(.system(size: 13, weight: .semibold))
                }
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 30)
                    .padding(.top, 2)

                Text(exercise.name)
                    .font(.system(size: 30, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 26)
                Text(exercise.amountText)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.quinary, in: Capsule())
                    .padding(.top, 10)

                if !exercise.tip.isEmpty {
                    Text(exercise.tip)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }

                if exercise.unit == .seconds {
                    Countdown(length: TimeInterval(exercise.amount))
                        .padding(.top, 18)
                }
            }
            .padding(EdgeInsets(top: 28, leading: 28, bottom: 26, trailing: 28))

            Divider()

            HStack(spacing: 8) {
                Button("Snooze \(snoozeMinutes) min") { finish(.snoozed) }
                Button("Skip") { finish(.skipped) }
                Spacer()
                Button { finish(.done) } label: { Text("Done").frame(minWidth: 96) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(.quinary)
        }
        .frame(width: 444)
        .ignoresSafeArea()
    }
}

private struct Countdown: View {
    let length: TimeInterval
    @State private var startedAt: Date?
    @State private var elapsed: TimeInterval = 0

    private var isFinished: Bool { startedAt != nil && elapsed >= length }
    private var isRunning: Bool { startedAt != nil && !isFinished }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                elapsed = 0
                startedAt = isRunning ? nil : Date()
            } label: {
                switch (isRunning, isFinished) {
                case (true, _): Label("Stop", systemImage: "stop.fill")
                case (_, true): Label("Again", systemImage: "arrow.clockwise")
                default: Label("Start timer", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderless)

            ProgressView(value: min(elapsed / length, 1))
                .opacity(startedAt == nil ? 0 : 1)

            Text(isFinished ? "Time's up" : Self.clock(length - elapsed))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .task(id: startedAt) {
            guard let startedAt else {
                return
            }

            while !Task.isCancelled {
                elapsed = Date().timeIntervalSince(startedAt)
                if elapsed >= length {
                    Chime.playBell()
                    return
                }

                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private static func clock(_ remaining: TimeInterval) -> String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
