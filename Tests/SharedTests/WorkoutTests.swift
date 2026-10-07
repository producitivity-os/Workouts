import Foundation
import SwiftData
import Testing
@testable import Workouts

private func workoutContainer() throws -> ModelContainer {
    let schema = Schema(WorkoutSchemaV1.models)
    let configuration = ModelConfiguration("WorkoutTests", schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}

@Test func metCalorieEstimateUsesBodyMassAndDuration() {
    let value = WorkoutCalorieEstimator.estimate(met: 8, bodyMassKilograms: 70, durationSeconds: 1_800)
    #expect(abs(value - 294) < 0.001)
    #expect(WorkoutCalorieEstimator.preferred(estimated: value, healthKitActual: 320) == 320)
}

@Test func exerciseVariantsPersistTheirSpecificFields() async throws {
    let store = WorkoutStoreActor(modelContainer: try workoutContainer())
    try await store.seedIfNeeded()
    var draft = ExerciseDraft()
    draft.name = "Bench Press"
    draft.kind = .repetitions
    draft.repetitionStyle = .weighted
    draft.sets = 5
    draft.repetitions = 5
    draft.weightKilograms = 80
    let id = try await store.saveExercise(draft)
    let loaded = try #require(await store.exerciseDraft(id: id))
    #expect(loaded.repetitionStyle == .weighted)
    #expect(loaded.sets == 5)
    #expect(loaded.weightKilograms == 80)
}

@Test func onlyOneLiveSessionRunsAtATime() async throws {
    let store = WorkoutStoreActor(modelContainer: try workoutContainer())
    try await store.seedIfNeeded()
    let first = try await store.startSession(templateID: nil, name: "First")
    let second = try await store.startSession(templateID: nil, name: "Second")
    let sessions = try await store.sessions()
    #expect(sessions.first(where: { $0.id == first })?.state == .paused)
    #expect(sessions.first(where: { $0.id == second })?.state == .active)
}

@Test func mediaIsDeduplicatedByContentHash() async throws {
    let store = WorkoutStoreActor(modelContainer: try workoutContainer())
    try await store.seedIfNeeded()
    var first = ExerciseDraft()
    first.name = "One"
    first.kind = .timed
    first.mediaName = "move.gif"
    first.mediaMIMEType = "image/gif"
    first.mediaData = Data([1, 2, 3])
    var second = first
    second.id = nil
    second.name = "Two"
    _ = try await store.saveExercise(first)
    _ = try await store.saveExercise(second)
    #expect(try await store.mediaCount() == 1)
}
