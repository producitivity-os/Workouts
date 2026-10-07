import Foundation
import SwiftData

enum ExerciseKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case distance
    case repetitions
    case timed

    var id: String { rawValue }
    var title: String {
        switch self {
        case .distance: "Distance"
        case .repetitions: "Repetitions"
        case .timed: "Timed"
        }
    }
}

enum DistanceActivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case running, cycling
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum RepetitionStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case bodyweight, weighted, resistance
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum TimedActivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case stretch, jumpRope, plank, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .jumpRope: "Jump Rope"
        default: rawValue.capitalized
        }
    }
}

enum WorkoutSessionSource: String, Codable, Sendable {
    case live, manual
}

enum WorkoutSessionState: String, Codable, Sendable {
    case active, paused, completed, cancelled
}

@Model
final class WorkoutPreferences {
    @Attribute(.unique) var id: String
    var bodyMassKilograms: Double
    var healthKitEnabled: Bool

    init(bodyMassKilograms: Double = 70, healthKitEnabled: Bool = false) {
        id = "default"
        self.bodyMassKilograms = bodyMassKilograms
        self.healthKitEnabled = healthKitEnabled
    }
}

@Model
final class ExerciseMediaAsset {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var contentHash: String
    var originalName: String
    var mimeType: String
    @Attribute(.externalStorage) var data: Data
    @Attribute(.externalStorage) var posterData: Data?
    var createdAt: Date

    init(id: UUID = UUID(), contentHash: String, originalName: String, mimeType: String, data: Data, posterData: Data? = nil) {
        self.id = id
        self.contentHash = contentHash
        self.originalName = originalName
        self.mimeType = mimeType
        self.data = data
        self.posterData = posterData
        createdAt = .now
    }
}

@Model
final class ExerciseRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var exerciseDescription: String
    var kindRaw: String
    var metValue: Double
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var media: ExerciseMediaAsset?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseStep.exercise) var steps: [ExerciseStep]
    @Relationship(deleteRule: .cascade, inverse: \DistanceExerciseProfile.exercise) var distanceProfile: DistanceExerciseProfile?
    @Relationship(deleteRule: .cascade, inverse: \RepExerciseProfile.exercise) var repProfile: RepExerciseProfile?
    @Relationship(deleteRule: .cascade, inverse: \TimedExerciseProfile.exercise) var timedProfile: TimedExerciseProfile?

    var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .timed }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), name: String, description: String = "", kind: ExerciseKind, metValue: Double) {
        self.id = id
        self.name = name
        exerciseDescription = description
        kindRaw = kind.rawValue
        self.metValue = metValue
        createdAt = .now
        updatedAt = .now
        steps = []
    }
}

@Model
final class ExerciseStep {
    @Attribute(.unique) var id: UUID
    var position: Int
    var instruction: String
    var exercise: ExerciseRecord?

    init(id: UUID = UUID(), position: Int, instruction: String, exercise: ExerciseRecord? = nil) {
        self.id = id
        self.position = position
        self.instruction = instruction
        self.exercise = exercise
    }
}

@Model
final class DistanceExerciseProfile {
    @Attribute(.unique) var id: UUID
    var activityRaw: String
    var defaultDistanceMeters: Double
    var defaultDurationSeconds: Double
    var isIndoor: Bool
    var exercise: ExerciseRecord?

    var activity: DistanceActivity {
        get { DistanceActivity(rawValue: activityRaw) ?? .running }
        set { activityRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), activity: DistanceActivity, distanceMeters: Double = 5_000, durationSeconds: Double = 1_800, isIndoor: Bool = false, exercise: ExerciseRecord? = nil) {
        self.id = id
        activityRaw = activity.rawValue
        defaultDistanceMeters = distanceMeters
        defaultDurationSeconds = durationSeconds
        self.isIndoor = isIndoor
        self.exercise = exercise
    }
}

@Model
final class RepExerciseProfile {
    @Attribute(.unique) var id: UUID
    var styleRaw: String
    var defaultSets: Int
    var defaultRepetitions: Int
    var defaultWeightKilograms: Double?
    var resistanceLabel: String
    var isUnilateral: Bool
    var exercise: ExerciseRecord?

    var style: RepetitionStyle {
        get { RepetitionStyle(rawValue: styleRaw) ?? .bodyweight }
        set { styleRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), style: RepetitionStyle, sets: Int = 3, repetitions: Int = 10, weightKilograms: Double? = nil, resistanceLabel: String = "", isUnilateral: Bool = false, exercise: ExerciseRecord? = nil) {
        self.id = id
        styleRaw = style.rawValue
        defaultSets = sets
        defaultRepetitions = repetitions
        defaultWeightKilograms = weightKilograms
        self.resistanceLabel = resistanceLabel
        self.isUnilateral = isUnilateral
        self.exercise = exercise
    }
}

@Model
final class TimedExerciseProfile {
    @Attribute(.unique) var id: UUID
    var activityRaw: String
    var defaultDurationSeconds: Double
    var exercise: ExerciseRecord?

    var activity: TimedActivity {
        get { TimedActivity(rawValue: activityRaw) ?? .other }
        set { activityRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), activity: TimedActivity, durationSeconds: Double = 60, exercise: ExerciseRecord? = nil) {
        self.id = id
        activityRaw = activity.rawValue
        defaultDurationSeconds = durationSeconds
        self.exercise = exercise
    }
}

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String
    var scheduledWeekdays: [Int]
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \WorkoutBlock.template) var blocks: [WorkoutBlock]

    init(id: UUID = UUID(), name: String, notes: String = "", scheduledWeekdays: [Int] = []) {
        self.id = id
        self.name = name
        self.notes = notes
        self.scheduledWeekdays = scheduledWeekdays
        createdAt = .now
        updatedAt = .now
        blocks = []
    }
}

@Model
final class WorkoutBlock {
    @Attribute(.unique) var id: UUID
    var position: Int
    var targetSets: Int
    var targetRepetitions: Int?
    var targetDistanceMeters: Double?
    var targetDurationSeconds: Double?
    var targetWeightKilograms: Double?
    var restSeconds: Double
    var template: WorkoutTemplate?
    var exercise: ExerciseRecord?

    init(id: UUID = UUID(), position: Int, exercise: ExerciseRecord? = nil, sets: Int = 1, repetitions: Int? = nil, distanceMeters: Double? = nil, durationSeconds: Double? = nil, weightKilograms: Double? = nil, restSeconds: Double = 60, template: WorkoutTemplate? = nil) {
        self.id = id
        self.position = position
        targetSets = sets
        targetRepetitions = repetitions
        targetDistanceMeters = distanceMeters
        targetDurationSeconds = durationSeconds
        targetWeightKilograms = weightKilograms
        self.restSeconds = restSeconds
        self.template = template
        self.exercise = exercise
    }
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var templateID: UUID?
    var workoutName: String
    var sourceRaw: String
    var stateRaw: String
    var startedAt: Date
    var completedAt: Date?
    var activeSince: Date?
    var accumulatedSeconds: Double
    var estimatedCalories: Double
    var actualCalories: Double?
    var healthKitWorkoutID: String?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session) var logs: [ExerciseLog]

    var state: WorkoutSessionState {
        get { WorkoutSessionState(rawValue: stateRaw) ?? .paused }
        set { stateRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), templateID: UUID? = nil, workoutName: String, source: WorkoutSessionSource, state: WorkoutSessionState = .active, startedAt: Date = .now) {
        self.id = id
        self.templateID = templateID
        self.workoutName = workoutName
        sourceRaw = source.rawValue
        stateRaw = state.rawValue
        self.startedAt = startedAt
        activeSince = state == .active ? startedAt : nil
        accumulatedSeconds = 0
        estimatedCalories = 0
        logs = []
    }
}

@Model
final class ExerciseLog {
    @Attribute(.unique) var id: UUID
    var exerciseID: UUID
    var exerciseName: String
    var position: Int
    var completedSets: Int
    var repetitions: Int?
    var distanceMeters: Double?
    var durationSeconds: Double
    var weightKilograms: Double?
    var estimatedCalories: Double
    var actualCalories: Double?
    var session: WorkoutSession?

    init(id: UUID = UUID(), exerciseID: UUID, exerciseName: String, position: Int, completedSets: Int = 1, repetitions: Int? = nil, distanceMeters: Double? = nil, durationSeconds: Double = 0, weightKilograms: Double? = nil, estimatedCalories: Double = 0, session: WorkoutSession? = nil) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.position = position
        self.completedSets = completedSets
        self.repetitions = repetitions
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.weightKilograms = weightKilograms
        self.estimatedCalories = estimatedCalories
        self.session = session
    }
}

enum WorkoutSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [WorkoutPreferences.self, ExerciseMediaAsset.self, ExerciseRecord.self, ExerciseStep.self,
         DistanceExerciseProfile.self, RepExerciseProfile.self, TimedExerciseProfile.self,
         WorkoutTemplate.self, WorkoutBlock.self, WorkoutSession.self, ExerciseLog.self]
    }
}

enum WorkoutMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [WorkoutSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
