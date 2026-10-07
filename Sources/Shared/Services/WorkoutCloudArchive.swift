import Foundation
import ProductivityCloudKit
import SwiftData

private struct ExerciseCloudArchive: Codable {
    struct Step: Codable { let id: UUID; var position: Int; var instruction: String }
    struct Distance: Codable { let id: UUID; var activity: DistanceActivity; var distance: Double; var duration: Double; var isIndoor: Bool }
    struct Repetitions: Codable { let id: UUID; var style: RepetitionStyle; var sets: Int; var repetitions: Int; var weight: Double?; var resistance: String; var unilateral: Bool }
    struct Timed: Codable { let id: UUID; var activity: TimedActivity; var duration: Double }
    struct Media: Codable { let id: UUID; var hash: String; var name: String; var mimeType: String; var poster: Data?; var createdAt: Date }

    let id: UUID
    var name: String
    var details: String
    var kind: ExerciseKind
    var metValue: Double
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var steps: [Step]
    var distance: Distance?
    var repetitions: Repetitions?
    var timed: Timed?
    var media: Media?
}

private struct WorkoutTemplateCloudArchive: Codable {
    struct Block: Codable {
        let id: UUID
        var position: Int
        var exerciseID: UUID?
        var sets: Int
        var repetitions: Int?
        var distance: Double?
        var duration: Double?
        var weight: Double?
        var rest: Double
    }
    let id: UUID
    var name: String
    var notes: String
    var weekdays: [Int]
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var blocks: [Block]
}

extension WorkoutStoreActor {
    func cloudRecords() throws -> [CloudSyncRecord] {
        let exercises = try modelContext.fetch(FetchDescriptor<ExerciseRecord>())
        let templates = try modelContext.fetch(FetchDescriptor<WorkoutTemplate>())
        var records = try exercises.map(exerciseCloudRecord)
        records += try templates.map(templateCloudRecord)
        return records
    }

    func applyCloudRecords(_ records: [CloudSyncRecord], deletions: [String]) throws {
        for record in records where record.recordType == "Exercise" { try applyExercise(record) }
        for record in records where record.recordType == "WorkoutTemplate" { try applyTemplate(record) }
        for value in deletions {
            guard let id = UUID(uuidString: value) else { continue }
            let exerciseDescriptor = FetchDescriptor<ExerciseRecord>(predicate: #Predicate { $0.id == id })
            if let exercise = try modelContext.fetch(exerciseDescriptor).first {
                exercise.archivedAt = exercise.archivedAt ?? .now
                exercise.updatedAt = .now
            }
            let templateDescriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.id == id })
            if let template = try modelContext.fetch(templateDescriptor).first {
                template.archivedAt = template.archivedAt ?? .now
                template.updatedAt = .now
            }
        }
        try modelContext.save()
    }

    private func exerciseCloudRecord(_ exercise: ExerciseRecord) throws -> CloudSyncRecord {
        let archive = ExerciseCloudArchive(
            id: exercise.id,
            name: exercise.name,
            details: exercise.exerciseDescription,
            kind: exercise.kind,
            metValue: exercise.metValue,
            archivedAt: exercise.archivedAt,
            createdAt: exercise.createdAt,
            updatedAt: exercise.updatedAt,
            steps: exercise.steps.map { .init(id: $0.id, position: $0.position, instruction: $0.instruction) },
            distance: exercise.distanceProfile.map { .init(id: $0.id, activity: $0.activity, distance: $0.defaultDistanceMeters, duration: $0.defaultDurationSeconds, isIndoor: $0.isIndoor) },
            repetitions: exercise.repProfile.map { .init(id: $0.id, style: $0.style, sets: $0.defaultSets, repetitions: $0.defaultRepetitions, weight: $0.defaultWeightKilograms, resistance: $0.resistanceLabel, unilateral: $0.isUnilateral) },
            timed: exercise.timedProfile.map { .init(id: $0.id, activity: $0.activity, duration: $0.defaultDurationSeconds) },
            media: exercise.media.map { .init(id: $0.id, hash: $0.contentHash, name: $0.originalName, mimeType: $0.mimeType, poster: $0.posterData, createdAt: $0.createdAt) }
        )
        var assets: [String: URL] = [:]
        if let media = exercise.media {
            let directory = URL.applicationSupportDirectory.appending(path: "Workouts/CloudAssets", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: media.contentHash, directoryHint: .notDirectory)
            if !FileManager.default.fileExists(atPath: url.path) { try media.data.write(to: url, options: .atomic) }
            assets["media"] = url
        }
        return CloudSyncRecord(id: exercise.id.uuidString, recordType: "Exercise", updatedAt: exercise.updatedAt, archivedAt: exercise.archivedAt, payload: try JSONEncoder().encode(archive), assets: assets)
    }

    private func templateCloudRecord(_ template: WorkoutTemplate) throws -> CloudSyncRecord {
        let archive = WorkoutTemplateCloudArchive(
            id: template.id,
            name: template.name,
            notes: template.notes,
            weekdays: template.scheduledWeekdays,
            archivedAt: template.archivedAt,
            createdAt: template.createdAt,
            updatedAt: template.updatedAt,
            blocks: template.blocks.map {
                .init(id: $0.id, position: $0.position, exerciseID: $0.exercise?.id, sets: $0.targetSets, repetitions: $0.targetRepetitions, distance: $0.targetDistanceMeters, duration: $0.targetDurationSeconds, weight: $0.targetWeightKilograms, rest: $0.restSeconds)
            }
        )
        return CloudSyncRecord(id: template.id.uuidString, recordType: "WorkoutTemplate", updatedAt: template.updatedAt, archivedAt: template.archivedAt, payload: try JSONEncoder().encode(archive))
    }

    private func applyExercise(_ record: CloudSyncRecord) throws {
        let archive = try JSONDecoder().decode(ExerciseCloudArchive.self, from: record.payload)
        let id = archive.id
        let descriptor = FetchDescriptor<ExerciseRecord>(predicate: #Predicate { $0.id == id })
        let exercise = try modelContext.fetch(descriptor).first ?? ExerciseRecord(id: id, name: archive.name, kind: archive.kind, metValue: archive.metValue)
        guard exercise.modelContext == nil || archive.updatedAt > exercise.updatedAt else { return }
        if exercise.modelContext == nil { modelContext.insert(exercise) }
        exercise.name = archive.name
        exercise.exerciseDescription = archive.details
        exercise.kind = archive.kind
        exercise.metValue = archive.metValue
        exercise.archivedAt = archive.archivedAt
        exercise.createdAt = archive.createdAt
        exercise.updatedAt = archive.updatedAt

        exercise.steps.forEach(modelContext.delete)
        exercise.steps = archive.steps.map { ExerciseStep(id: $0.id, position: $0.position, instruction: $0.instruction, exercise: exercise) }
        if let value = archive.distance {
            exercise.distanceProfile = DistanceExerciseProfile(id: value.id, activity: value.activity, distanceMeters: value.distance, durationSeconds: value.duration, isIndoor: value.isIndoor, exercise: exercise)
        } else { exercise.distanceProfile = nil }
        if let value = archive.repetitions {
            exercise.repProfile = RepExerciseProfile(id: value.id, style: value.style, sets: value.sets, repetitions: value.repetitions, weightKilograms: value.weight, resistanceLabel: value.resistance, isUnilateral: value.unilateral, exercise: exercise)
        } else { exercise.repProfile = nil }
        if let value = archive.timed {
            exercise.timedProfile = TimedExerciseProfile(id: value.id, activity: value.activity, durationSeconds: value.duration, exercise: exercise)
        } else { exercise.timedProfile = nil }

        if let metadata = archive.media, let url = record.assets["media"], let data = try? Data(contentsOf: url) {
            let mediaDescriptor = FetchDescriptor<ExerciseMediaAsset>(predicate: #Predicate { $0.contentHash == metadata.hash })
            exercise.media = try modelContext.fetch(mediaDescriptor).first ?? ExerciseMediaAsset(id: metadata.id, contentHash: metadata.hash, originalName: metadata.name, mimeType: metadata.mimeType, data: data, posterData: metadata.poster)
        }
    }

    private func applyTemplate(_ record: CloudSyncRecord) throws {
        let archive = try JSONDecoder().decode(WorkoutTemplateCloudArchive.self, from: record.payload)
        let id = archive.id
        let descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.id == id })
        let template = try modelContext.fetch(descriptor).first ?? WorkoutTemplate(id: id, name: archive.name)
        guard template.modelContext == nil || archive.updatedAt > template.updatedAt else { return }
        if template.modelContext == nil { modelContext.insert(template) }
        template.name = archive.name
        template.notes = archive.notes
        template.scheduledWeekdays = archive.weekdays
        template.archivedAt = archive.archivedAt
        template.createdAt = archive.createdAt
        template.updatedAt = archive.updatedAt
        template.blocks.forEach(modelContext.delete)
        template.blocks = try archive.blocks.map { value in
            let exercise: ExerciseRecord?
            if let exerciseID = value.exerciseID {
                let descriptor = FetchDescriptor<ExerciseRecord>(predicate: #Predicate { $0.id == exerciseID })
                exercise = try modelContext.fetch(descriptor).first
            } else { exercise = nil }
            return WorkoutBlock(id: value.id, position: value.position, exercise: exercise, sets: value.sets, repetitions: value.repetitions, distanceMeters: value.distance, durationSeconds: value.duration, weightKilograms: value.weight, restSeconds: value.rest, template: template)
        }
    }
}
