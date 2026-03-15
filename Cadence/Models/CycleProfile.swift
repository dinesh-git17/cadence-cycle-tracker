import Foundation

struct CycleProfile: Codable, Sendable {
    let userId: UUID
    let averageCycleLength: Int
    let averagePeriodLength: Int
    let goalMode: GoalMode
    let predictionsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case averageCycleLength = "average_cycle_length"
        case averagePeriodLength = "average_period_length"
        case goalMode = "goal_mode"
        case predictionsEnabled = "predictions_enabled"
    }
}
