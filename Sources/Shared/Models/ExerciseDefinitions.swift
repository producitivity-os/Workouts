import Foundation

class ExerciseDefinition: Identifiable {
    let id: UUID
    let name: String
    let metValue: Double

    init(id: UUID, name: String, metValue: Double) {
        self.id = id
        self.name = name
        self.metValue = metValue
    }

    func estimatedCalories(bodyMassKilograms: Double, durationSeconds: Double) -> Double {
        WorkoutCalorieEstimator.estimate(met: metValue, bodyMassKilograms: bodyMassKilograms, durationSeconds: durationSeconds)
    }
}

final class DistanceExercise: ExerciseDefinition {
    let activity: DistanceActivity
    let distanceMeters: Double
    let expectedDurationSeconds: Double
    let isIndoor: Bool

    init(record: ExerciseRecord, profile: DistanceExerciseProfile) {
        activity = profile.activity
        distanceMeters = profile.defaultDistanceMeters
        expectedDurationSeconds = profile.defaultDurationSeconds
        isIndoor = profile.isIndoor
        super.init(id: record.id, name: record.name, metValue: record.metValue)
    }
}

final class RepExercise: ExerciseDefinition {
    let style: RepetitionStyle
    let sets: Int
    let repetitions: Int
    let weightKilograms: Double?
    let resistanceLabel: String
    let isUnilateral: Bool

    init(record: ExerciseRecord, profile: RepExerciseProfile) {
        style = profile.style
        sets = profile.defaultSets
        repetitions = profile.defaultRepetitions
        weightKilograms = profile.defaultWeightKilograms
        resistanceLabel = profile.resistanceLabel
        isUnilateral = profile.isUnilateral
        super.init(id: record.id, name: record.name, metValue: record.metValue)
    }
}

final class TimedExercise: ExerciseDefinition {
    let activity: TimedActivity
    let durationSeconds: Double

    init(record: ExerciseRecord, profile: TimedExerciseProfile) {
        activity = profile.activity
        durationSeconds = profile.defaultDurationSeconds
        super.init(id: record.id, name: record.name, metValue: record.metValue)
    }
}

enum ExerciseDefinitionFactory {
    static func make(from record: ExerciseRecord) -> ExerciseDefinition? {
        switch record.kind {
        case .distance:
            record.distanceProfile.map { DistanceExercise(record: record, profile: $0) }
        case .repetitions:
            record.repProfile.map { RepExercise(record: record, profile: $0) }
        case .timed:
            record.timedProfile.map { TimedExercise(record: record, profile: $0) }
        }
    }
}
