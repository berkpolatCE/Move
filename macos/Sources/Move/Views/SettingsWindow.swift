import AppKit
import MoveCore
import SwiftUI

@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 620, height: 800),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false)
    private let onClose: (AppSettings?) -> Void
    private var result: AppSettings?

    init(settings: AppSettings, isFirstRun: Bool, onClose: @escaping (AppSettings?) -> Void) {
        self.onClose = onClose
        super.init()

        window.title = "Move settings"
        window.minSize = NSSize(width: 520, height: 480)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(
            rootView: SettingsView(
                settings: settings,
                isFirstRun: isFirstRun,
                save: { [weak self] updated in
                    self?.result = updated
                    self?.window.close()
                },
                cancel: { [weak self] in self?.window.close() }))
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose(result)
    }
}

private struct Choice<Value: Hashable>: Hashable {
    let value: Value
    let label: String

    static func minutes(_ presets: [Int], current: Int) -> [Choice<Int>] {
        Set(presets + [current]).sorted().map { Choice<Int>(value: $0, label: Phrasing.length(TimeInterval($0 * 60))) }
    }

    static func halfHours(current: TimeOfDay) -> [Choice<TimeOfDay>] {
        Set((0..<48).map { TimeOfDay(hour: $0 / 2, minute: $0 % 2 * 30) } + [current])
            .sorted()
            .map { Choice<TimeOfDay>(value: $0, label: $0.text) }
    }
}

private struct ExerciseDraft: Identifiable {
    let id = UUID()
    var name: String
    var amountText: String
    var unit: ExerciseUnit
    var tip: String

    init(_ exercise: Exercise) {
        name = exercise.name
        amountText = String(exercise.amount)
        unit = exercise.unit
        tip = exercise.tip
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled exercise" : trimmed
    }

    var amount: Int? {
        Int(amountText.trimmingCharacters(in: .whitespaces)).flatMap { (1...Exercise.maxAmount).contains($0) ? $0 : nil }
    }

    var summary: String {
        let amountText = amount.map { Exercise(name: name, amount: $0, unit: unit).amountText } ?? "No amount set"
        let tip = tip.trimmingCharacters(in: .whitespacesAndNewlines)
        return tip.isEmpty ? amountText : "\(amountText)  ·  \(tip)"
    }

    func problem(number: Int) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Exercise \(number) needs a name."
        }

        return amount == nil ? "\(displayName) needs an amount between 1 and \(Exercise.maxAmount)." : nil
    }

    var exercise: Exercise {
        Exercise(name: name, amount: amount ?? 0, unit: unit, tip: tip)
    }
}

private struct SettingsView: View {
    let isFirstRun: Bool
    let save: (AppSettings) -> Void
    let cancel: () -> Void

    private let intervalChoices: [Choice<Int>]
    private let idleResetChoices: [Choice<Int>]
    private let snoozeChoices: [Choice<Int>]
    private let activeFromChoices: [Choice<TimeOfDay>]
    private let activeToChoices: [Choice<TimeOfDay>]

    @State private var settings: AppSettings
    @State private var exercises: [ExerciseDraft]
    @State private var editing: ExerciseDraft.ID?
    @State private var error: String?
    @FocusState private var focusedName: ExerciseDraft.ID?

    init(settings: AppSettings, isFirstRun: Bool, save: @escaping (AppSettings) -> Void, cancel: @escaping () -> Void) {
        self.isFirstRun = isFirstRun
        self.save = save
        self.cancel = cancel
        intervalChoices = Choice<Int>.minutes([15, 20, 30, 45, 60, 90, 120], current: settings.intervalMinutes)
        idleResetChoices = Choice<Int>.minutes([2, 5, 10, 15, 20, 30], current: settings.idleResetMinutes)
        snoozeChoices = Choice<Int>.minutes([5, 10, 15, 20, 30], current: settings.snoozeMinutes)
        activeFromChoices = Choice<TimeOfDay>.halfHours(current: settings.activeHoursStart)
        activeToChoices = Choice<TimeOfDay>.halfHours(current: settings.activeHoursEnd)
        _settings = State(initialValue: settings)
        _exercises = State(initialValue: settings.exercises.map(ExerciseDraft.init))
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker(selection: $settings.intervalMinutes) {
                        ForEach(intervalChoices, id: \.value) { Text($0.label).tag($0.value) }
                    } label: {
                        Text("Remind me every")
                        Text("How long you can sit before Move suggests a break")
                    }

                    Picker(selection: $settings.timerMode) {
                        Text("Start the countdown over").tag(TimerMode.resetWhenIdle)
                        Text("Keep a fixed schedule").tag(TimerMode.fixedInterval)
                    } label: {
                        Text("When I step away")
                        Text(settings.timerMode == .resetWhenIdle
                            ? "Stepping away counts as your break"
                            : "Remind me every interval, even right after I've been away")
                    }
                    .pickerStyle(.radioGroup)

                    if settings.timerMode == .resetWhenIdle {
                        Picker(selection: $settings.idleResetMinutes) {
                            ForEach(idleResetChoices, id: \.value) { Text($0.label).tag($0.value) }
                        } label: {
                            Text("I'm away after")
                            Text("Without keyboard or mouse input")
                        }
                    }

                    Picker(selection: $settings.snoozeMinutes) {
                        ForEach(snoozeChoices, id: \.value) { Text($0.label).tag($0.value) }
                    } label: {
                        Text("Snooze for")
                        Text("How long Snooze holds off the reminder")
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        Text("Reminders").font(.headline)
                    }
                }

                Section("Schedule") {
                    Toggle(isOn: $settings.activeHoursEnabled) {
                        Text("Active hours")
                        Text("Only remind me during part of the day")
                    }

                    if settings.activeHoursEnabled {
                        LabeledContent("From") {
                            HStack {
                                Picker("From", selection: $settings.activeHoursStart) {
                                    ForEach(activeFromChoices, id: \.value) { Text($0.label).tag($0.value) }
                                }
                                Text("to")
                                Picker("To", selection: $settings.activeHoursEnd) {
                                    ForEach(activeToChoices, id: \.value) { Text($0.label).tag($0.value) }
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }

                Section("Exercises") {
                    Toggle(isOn: $settings.shuffleExercises) {
                        Text("Shuffle order")
                        Text("Every exercise still comes up once per round")
                    }
                }

                Section {
                    ForEach($exercises) { $exercise in
                        exerciseRow($exercise)
                    }

                    Button {
                        let exercise = ExerciseDraft(Exercise(name: "New exercise", amount: 10))
                        exercises.append(exercise)
                        editing = exercise.id
                        Task { focusedName = exercise.id }
                    } label: {
                        Label("Add exercise", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }

                Section("General") {
                    LabeledContent {
                        HStack(spacing: 12) {
                            Button { Chime.playBells() } label: { Image(systemName: "play.fill") }
                                .buttonStyle(.borderless)
                                .help("Play the chime")
                            Toggle("Chime", isOn: $settings.playChimeWithPopup)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    } label: {
                        Text("Chime")
                        Text("Plays with the popup. In fullscreen games and videos, Move always chimes and shows the exercise in a small corner notice instead.")
                    }

                    Toggle(isOn: $settings.openAtLogin) {
                        Text("Open at login")
                        Text("Open Move automatically when you log in")
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack(spacing: 8) {
                if let error {
                    Text(error).foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: submit)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                MoveLogo().frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Move").font(.system(size: 24, weight: .semibold)).foregroundStyle(.primary)
                    Text("Short exercise breaks while you work").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }

            if isFirstRun {
                Label {
                    Text("Move runs in the menu bar. Click its icon any time to see what's next, pause reminders, or come back here.")
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "info.circle.fill").foregroundStyle(.tint)
                }
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.bottom, 8)
    }

    private func exerciseRow(_ exercise: Binding<ExerciseDraft>) -> some View {
        let id = exercise.wrappedValue.id
        let index = exercises.firstIndex { $0.id == id } ?? 0
        let isEditing = editing == id

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quinary, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.wrappedValue.displayName).fontWeight(.semibold).lineLimit(1)
                    Text(exercise.wrappedValue.summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Group {
                    Button { exercises.swapAt(index, index - 1) } label: { Image(systemName: "arrow.up") }
                        .disabled(index == 0)
                        .help("Move up")
                    Button { exercises.swapAt(index, index + 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(index == exercises.count - 1)
                        .help("Move down")
                    Button { exercises.remove(at: index) } label: { Image(systemName: "trash") }
                        .disabled(exercises.count == 1)
                        .help("Remove")
                }
                .buttonStyle(.borderless)
                Image(systemName: isEditing ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { editing = isEditing ? nil : id }

            if isEditing {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Name").foregroundStyle(.secondary)
                        TextField("Name", text: exercise.name)
                            .focused($focusedName, equals: id)
                    }
                    GridRow {
                        Text("Amount").foregroundStyle(.secondary)
                        HStack {
                            TextField("Amount", text: exercise.amountText).frame(width: 90)
                            Picker("Unit", selection: exercise.unit) {
                                Text("reps").tag(ExerciseUnit.reps)
                                Text("seconds").tag(ExerciseUnit.seconds)
                            }
                            .fixedSize()
                        }
                    }
                    GridRow {
                        Text("Tip").foregroundStyle(.secondary)
                        TextField("Tip", text: exercise.tip, axis: .vertical)
                    }
                }
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .padding(.leading, 36)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func submit() {
        for (index, exercise) in exercises.enumerated() {
            if let problem = exercise.problem(number: index + 1) {
                editing = exercise.id
                error = problem
                return
            }
        }

        var updated = settings
        updated.exercises = exercises.map(\.exercise)
        save(updated.normalized())
    }
}
