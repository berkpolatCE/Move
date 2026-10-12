import Foundation

public enum ExerciseUnit: String, Codable, Sendable {
    case reps = "Reps"
    case seconds = "Seconds"
}

public struct Exercise: Codable, Equatable, Sendable {
    public static let maxAmount = 999

    public var name: String
    public var amount: Int
    public var unit: ExerciseUnit
    public var tip: String

    public init(name: String, amount: Int, unit: ExerciseUnit = .reps, tip: String = "") {
        self.name = name
        self.amount = amount
        self.unit = unit
        self.tip = tip
    }

    public var amountText: String {
        unit == .seconds ? Phrasing.count(amount, "second") : Phrasing.count(amount, "rep")
    }

    public static let defaults = [
        Exercise(name: "Jumping jacks", amount: 30, tip: "Land softly and keep a steady rhythm."),
        Exercise(name: "Squats", amount: 15, tip: "Feet shoulder-width apart, chest up, push through your heels."),
        Exercise(name: "Push-ups", amount: 10, tip: "Keep your body in a straight line. Knees on the floor is fine."),
        Exercise(name: "Wall sit", amount: 45, unit: .seconds, tip: "Back flat against the wall, knees bent to about 90 degrees."),
        Exercise(name: "Calf raises", amount: 20, tip: "Rise slowly onto your toes and lower back down with control."),
        Exercise(name: "Stretch", amount: 60, unit: .seconds, tip: "Reach overhead, fold forward, then roll your neck and shoulders."),
    ]

    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case amount = "Amount"
        case unit = "Unit"
        case tip = "Tip"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        amount = try container.decodeIfPresent(Int.self, forKey: .amount) ?? 0
        unit = try container.decodeIfPresent(ExerciseUnit.self, forKey: .unit) ?? .reps
        tip = try container.decodeIfPresent(String.self, forKey: .tip) ?? ""
    }
}
