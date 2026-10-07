import CryptoKit
import Foundation
import SwiftData

@ModelActor
actor WorkoutStoreActor {
    func seedIfNeeded() throws {
        if try modelContext.fetchCount(FetchDescriptor<WorkoutPreferences>()) == 0 {
            modelContext.insert(WorkoutPreferences())
        }
        guard try modelContext.fetchCount(FetchDescriptor<ExerciseRecord>()) == 0 else {
            try modelContext.save()
            return
        }

        let run = ExerciseRecord(name: "Outdoor Run", description: "A steady outdoor run.", kind: .distance, metValue: 9.8)
        run.distanceProfile = DistanceExerciseProfile(activity: .running, distanceMeters: 5_000, durationSeconds: 1_800, exercise: run)
        run.steps = [
            ExerciseStep(position: 0, instruction: "Warm up with an easy walk.", exercise: run),
            ExerciseStep(position: 1, instruction: "Run at a sustainable pace.", exercise: run),
            ExerciseStep(position: 2, instruction: "Cool down and stretch.", exercise: run)
        ]
        modelContext.insert(run)

        let pushups = ExerciseRecord(name: "Push-ups", description: "A bodyweight pressing exercise.", kind: .repetitions, metValue: 3.8)
        pushups.repProfile = RepExerciseProfile(style: .bodyweight, sets: 3, repetitions: 10, exercise: pushups)
        pushups.steps = [
            ExerciseStep(position: 0, instruction: "Place your hands slightly wider than shoulder width.", exercise: pushups),
            ExerciseStep(position: 1, instruction: "Lower your chest while keeping a straight line.", exercise: pushups),
            ExerciseStep(position: 2, instruction: "Press back to the starting position.", exercise: pushups)
        ]
        modelContext.insert(pushups)

        let plank = ExerciseRecord(name: "Plank", description: "A timed core hold.", kind: .timed, metValue: 3.0)
        plank.timedProfile = TimedExerciseProfile(activity: .plank, durationSeconds: 60, exercise: plank)
        plank.steps = [ExerciseStep(position: 0, instruction: "Hold a straight line from shoulders to heels.", exercise: plank)]
        modelContext.insert(plank)

        let stretch = ExerciseRecord(name: "Full-body Stretch", description: "A short mobility flow.", kind: .timed, metValue: 2.3)
        stretch.timedProfile = TimedExerciseProfile(activity: .stretch, durationSeconds: 600, exercise: stretch)
        stretch.steps = [ExerciseStep(position: 0, instruction: "Move gently through each stretch without bouncing.", exercise: stretch)]
        modelContext.insert(stretch)

        let template = WorkoutTemplate(name: "Daily Foundation", notes: "Run, strength, and core.", scheduledWeekdays: [2, 4, 6])
        template.blocks = [
            WorkoutBlock(position: 0, exercise: run, sets: 1, distanceMeters: 5_000, durationSeconds: 1_800, template: template),
            WorkoutBlock(position: 1, exercise: pushups, sets: 3, repetitions: 10, restSeconds: 60, template: template),
            WorkoutBlock(position: 2, exercise: plank, sets: 1, durationSeconds: 60, restSeconds: 30, template: template)
        ]
        modelContext.insert(template)
        try modelContext.save()
    }

    func exercises() throws -> [ExerciseSummary] {
        let descriptor = FetchDescriptor<ExerciseRecord>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor).map {
            ExerciseSummary(
                id: $0.id,
                name: $0.name,
                details: $0.exerciseDescription,
                kind: $0.kind,
                metValue: $0.metValue,
                stepCount: $0.steps.count,
                hasAnimation: $0.media != nil
            )
        }
    }

    func exerciseDraft(id: UUID) throws -> ExerciseDraft? {
        let descriptor = FetchDescriptor<ExerciseRecord>(predicate: #Predicate { $0.id == id })
        guard let value = try modelContext.fetch(descriptor).first else { return nil }
        var draft = ExerciseDraft()
        draft.id = value.id
        draft.name = value.name
        draft.details = value.exerciseDescription
        draft.kind = value.kind
        draft.metValue = value.metValue
        draft.steps = value.steps.sorted { $0.position < $1.position }.map(\.instruction)
        if let profile = value.distanceProfile {
            draft.distanceActivity = profile.activity
            draft.distanceMeters = profile.defaultDistanceMeters
            draft.durationSeconds = profile.defaultDurationSeconds
            draft.isIndoor = profile.isIndoor
        }
        if let profile = value.repProfile {
            draft.repetitionStyle = profile.style
            draft.sets = profile.defaultSets
            draft.repetitions = profile.defaultRepetitions
            draft.weightKilograms = profile.defaultWeightKilograms
            draft.resistanceLabel = profile.resistanceLabel
            draft.isUnilateral = profile.isUnilateral
        }
        if let profile = value.timedProfile {
            draft.timedActivity = profile.activity
            draft.durationSeconds = profile.defaultDurationSeconds
        }
        draft.mediaName = value.media?.originalName
        draft.mediaMIMEType = value.media?.mimeType
        draft.mediaData = value.media?.data
        return draft
    }

    @discardableResult
    func saveExercise(_ draft: ExerciseDraft) throws -> UUID {
        let value: ExerciseRecord
        if let id = draft.id {
            let descriptor = FetchDescriptor<ExerciseRecord>(predicate: #Predicate { $0.id == id })
            value = try modelContext.fetch(descriptor).first ?? ExerciseRecord(id: id, name: draft.name, kind: draft.kind, metValue: draft.metValue)
            if value.modelContext == nil { modelContext.insert(value) }
        } else {
            value = ExerciseRecord(name: draft.name, kind: draft.kind, metValue: draft.metValue)
            modelContext.insert(value)
        }
        value.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.exerciseDescription = draft.details
        value.kind = draft.kind
        value.metValue = max(0, draft.metValue)
        value.updatedAt = .now
        value.steps.forEach(modelContext.delete)
        value.steps = draft.steps.enumerated().compactMap { index, text in
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : ExerciseStep(position: index, instruction: cleaned, exercise: value)
        }
        if let old = value.distanceProfile { modelContext.delete(old); value.distanceProfile = nil }
        if let old = value.repProfile { modelContext.delete(old); value.repProfile = nil }
        if let old = value.timedProfile { modelContext.delete(old); value.timedProfile = nil }
        switch draft.kind {
        case .distance:
            value.distanceProfile = DistanceExerciseProfile(activity: draft.distanceActivity, distanceMeters: max(0, draft.distanceMeters), durationSeconds: max(1, draft.durationSeconds), isIndoor: draft.isIndoor, exercise: value)
        case .repetitions:
            value.repProfile = RepExerciseProfile(style: draft.repetitionStyle, sets: max(1, draft.sets), repetitions: max(1, draft.repetitions), weightKilograms: draft.weightKilograms, resistanceLabel: draft.resistanceLabel, isUnilateral: draft.isUnilateral, exercise: value)
        case .timed:
            value.timedProfile = TimedExerciseProfile(activity: draft.timedActivity, durationSeconds: max(1, draft.durationSeconds), exercise: value)
        }
        if let data = draft.mediaData, let name = draft.mediaName, let type = draft.mediaMIMEType {
            value.media = try mediaAsset(data: data, name: name, mimeType: type)
        }
        try modelContext.save()
        return value.id
    }

    func archiveExercise(id: UUID) throws {
        let descriptor = FetchDescriptor<ExerciseRecord>(predicate: #Predicate { $0.id == id })
        guard let value = try modelContext.fetch(descriptor).first else { return }
        value.archivedAt = .now
        value.updatedAt = .now
        try modelContext.save()
    }

    func templates() throws -> [WorkoutTemplateSummary] {
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: #Predicate { $0.archivedAt == nil },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor).map {
            WorkoutTemplateSummary(
                id: $0.id,
                name: $0.name,
                notes: $0.notes,
                scheduledWeekdays: $0.scheduledWeekdays,
                exerciseNames: $0.blocks.sorted { $0.position < $1.position }.compactMap { $0.exercise?.name }
            )
        }
    }

    func sessions() throws -> [WorkoutSessionSummary] {
        let descriptor = FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map { summary($0) }
    }

    func activeSession() throws -> WorkoutSessionSummary? {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate {
            $0.stateRaw == "active" || $0.stateRaw == "paused"
        }, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).first.map { summary($0) }
    }

    @discardableResult
    func startSession(templateID: UUID?, name: String, source: WorkoutSessionSource = .live) throws -> UUID {
        let open = try modelContext.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate {
            $0.stateRaw == "active"
        }))
        for session in open { pause(session, at: .now) }
        let session = WorkoutSession(templateID: templateID, workoutName: name, source: source)
        modelContext.insert(session)
        try modelContext.save()
        return session.id
    }

    func pauseSession(id: UUID, at date: Date = .now) throws {
        guard let session = try findSession(id) else { return }
        pause(session, at: date)
        try modelContext.save()
    }

    func resumeSession(id: UUID, at date: Date = .now) throws {
        guard let session = try findSession(id), session.state == .paused else { return }
        let active = try modelContext.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate {
            $0.stateRaw == "active"
        }))
        for other in active where other.id != id { pause(other, at: date) }
        session.state = .active
        session.activeSince = date
        try modelContext.save()
    }

    @discardableResult
    func completeSession(id: UUID, at date: Date = .now, actualCalories: Double? = nil, healthKitID: String? = nil) throws -> WorkoutSessionSummary? {
        guard let session = try findSession(id) else { return nil }
        if session.state == .active, let activeSince = session.activeSince {
            session.accumulatedSeconds += max(0, date.timeIntervalSince(activeSince))
        }
        session.state = .completed
        session.activeSince = nil
        session.completedAt = date
        session.actualCalories = actualCalories
        session.healthKitWorkoutID = healthKitID
        try modelContext.save()
        return summary(session)
    }

    func preferences() throws -> (bodyMass: Double, healthEnabled: Bool) {
        let value = try modelContext.fetch(FetchDescriptor<WorkoutPreferences>()).first ?? WorkoutPreferences()
        if value.modelContext == nil { modelContext.insert(value); try modelContext.save() }
        return (value.bodyMassKilograms, value.healthKitEnabled)
    }

    func mediaCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<ExerciseMediaAsset>())
    }

    func updatePreferences(bodyMass: Double, healthEnabled: Bool) throws {
        let value = try modelContext.fetch(FetchDescriptor<WorkoutPreferences>()).first ?? WorkoutPreferences()
        if value.modelContext == nil { modelContext.insert(value) }
        value.bodyMassKilograms = max(1, bodyMass)
        value.healthKitEnabled = healthEnabled
        try modelContext.save()
    }

    private func findSession(_ id: UUID) throws -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    private func pause(_ session: WorkoutSession, at date: Date) {
        guard session.state == .active else { return }
        if let activeSince = session.activeSince {
            session.accumulatedSeconds += max(0, date.timeIntervalSince(activeSince))
        }
        session.activeSince = nil
        session.state = .paused
    }

    private func summary(_ session: WorkoutSession) -> WorkoutSessionSummary {
        return WorkoutSessionSummary(
            id: session.id,
            name: session.workoutName,
            state: session.state,
            startedAt: session.startedAt,
            completedAt: session.completedAt,
            activeSince: session.activeSince,
            // The view advances a running session from `activeSince`. Keeping the
            // stored snapshot at committed elapsed time avoids counting that span twice.
            elapsedSeconds: session.accumulatedSeconds,
            estimatedCalories: session.estimatedCalories,
            actualCalories: session.actualCalories
        )
    }

    private func mediaAsset(data: Data, name: String, mimeType: String) throws -> ExerciseMediaAsset {
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let descriptor = FetchDescriptor<ExerciseMediaAsset>(predicate: #Predicate { $0.contentHash == hash })
        if let existing = try modelContext.fetch(descriptor).first { return existing }
        let value = ExerciseMediaAsset(contentHash: hash, originalName: name, mimeType: mimeType, data: data)
        modelContext.insert(value)
        return value
    }
}
