import Foundation

enum WorkoutSessionStatus: String, CaseIterable, Codable {
    case planned
    case active
    case completed
    case cancelled
}
