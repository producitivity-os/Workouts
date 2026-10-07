import Foundation

struct ExerciseSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let details: String
    let kind: ExerciseKind
    let metValue: Double
    let stepCount: Int
    let hasAnimation: Bool
}

struct WorkoutTemplateSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let notes: String
    let scheduledWeekdays: [Int]
    let exerciseNames: [String]
}

struct WorkoutSessionSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let state: WorkoutSessionState
    let startedAt: Date
    let completedAt: Date?
    let activeSince: Date?
    let elapsedSeconds: Double
    let estimatedCalories: Double
    let actualCalories: Double?
}

struct ExerciseDraft: Sendable {
    var id: UUID?
    var name = ""
    var details = ""
    var kind = ExerciseKind.repetitions
    var metValue = 4.0
    var steps: [String] = []
    var distanceActivity = DistanceActivity.running
    var distanceMeters = 5_000.0
    var durationSeconds = 60.0
    var isIndoor = false
    var repetitionStyle = RepetitionStyle.bodyweight
    var sets = 3
    var repetitions = 10
    var weightKilograms: Double?
    var resistanceLabel = ""
    var isUnilateral = false
    var timedActivity = TimedActivity.other
    var mediaName: String?
    var mediaMIMEType: String?
    var mediaData: Data?
}
