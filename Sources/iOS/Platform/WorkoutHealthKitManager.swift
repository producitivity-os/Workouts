import Foundation
import HealthKit
import Observation

enum WorkoutHealthAccessState: String, Sendable {
    case disabled, unavailable, ready, denied, failed
}

@MainActor @Observable
final class WorkoutHealthKitManager {
    private let store = HKHealthStore()
    private(set) var state: WorkoutHealthAccessState = HKHealthStore.isHealthDataAvailable() ? .disabled : .unavailable
    private(set) var lastError: String?

    private var workoutType: HKWorkoutType { HKObjectType.workoutType() }
    private var energyType: HKQuantityType { HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)! }
    private var runningDistanceType: HKQuantityType { HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)! }
    private var cyclingDistanceType: HKQuantityType { HKQuantityType.quantityType(forIdentifier: .distanceCycling)! }
    private var bodyMassType: HKQuantityType { HKQuantityType.quantityType(forIdentifier: .bodyMass)! }

    func requestAccess() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { state = .unavailable; return false }
        do {
            try await store.requestAuthorization(
                toShare: [workoutType, energyType, runningDistanceType, cyclingDistanceType],
                read: [workoutType, energyType, bodyMassType, runningDistanceType, cyclingDistanceType]
            )
            state = .ready
            lastError = nil
            return true
        } catch {
            state = .denied
            lastError = error.localizedDescription
            return false
        }
    }

    func latestBodyMassKilograms() async throws -> Double? {
        let descriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: bodyMassType, predicate: nil, limit: 1, sortDescriptors: [descriptor]) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    func saveCompletedSession(_ session: WorkoutSessionSummary) async throws -> (calories: Double?, identifier: String?) {
        guard state == .ready else { return (nil, nil) }
        if let existing = try await workout(sessionID: session.id) {
            return (existing.totalEnergyBurned?.doubleValue(for: .kilocalorie()), existing.uuid.uuidString)
        }
        let end = Date()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .unknown
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: session.startedAt)
        try await builder.addMetadata(["com.productivitysuite.workouts.session-id": session.id.uuidString])
        let calories = session.actualCalories ?? session.estimatedCalories
        if calories > 0 {
            let sample = HKQuantitySample(type: energyType, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories), start: session.startedAt, end: end)
            try await builder.addSamples([sample])
        }
        try await builder.endCollection(at: end)
        let workout = try await builder.finishWorkout()
        return (workout?.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? calories, workout?.uuid.uuidString)
    }

    private func workout(sessionID: UUID) async throws -> HKWorkout? {
        let predicate = HKQuery.predicateForObjects(withMetadataKey: "com.productivitysuite.workouts.session-id", allowedValues: [sessionID.uuidString])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples?.first as? HKWorkout)
            }
            store.execute(query)
        }
    }
}
