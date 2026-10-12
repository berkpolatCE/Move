import Foundation

public struct SettingsStore: Sendable {
    public static let `default` = SettingsStore(
        directory: URL.applicationSupportDirectory.appending(path: "Move", directoryHint: .isDirectory))

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private var settingsURL: URL { directory.appending(path: "settings.json") }
    private var rotationURL: URL { directory.appending(path: "rotation.json") }

    public var settingsExist: Bool { FileManager.default.fileExists(atPath: settingsURL.path) }

    public func loadSettings() -> AppSettings { (read(AppSettings.self, from: settingsURL) ?? AppSettings()).normalized() }

    @discardableResult
    public func saveSettings(_ settings: AppSettings) -> Bool { write(settings, to: settingsURL) }

    public func loadRotation() -> RotationState { read(RotationState.self, from: rotationURL) ?? RotationState() }

    @discardableResult
    public func saveRotation(_ state: RotationState) -> Bool { write(state, to: rotationURL) }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            try encoder.encode(value).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
