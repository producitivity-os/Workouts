import Foundation
import Observation
import ProductivityCloudKit
import ProductivityRoutineKit
import SwiftData

@MainActor @Observable
final class WorkoutsAppState {
    let container: ModelContainer
    let store: WorkoutStoreActor
    private(set) var exercises: [ExerciseSummary] = []
    private(set) var templates: [WorkoutTemplateSummary] = []
    private(set) var sessions: [WorkoutSessionSummary] = []
    private(set) var activeSession: WorkoutSessionSummary?
    private(set) var activeLogs: [WorkoutExerciseLogSummary] = []
    private(set) var completedRecap: WorkoutSessionSummary?
    var isReady = false
    var errorMessage: String?
    var cloudStatus = "Local only"
    var pendingExerciseID: UUID?
    private var routineInvocationID: UUID?
    private var cloudSync: ProductivityCloudSyncEngine?
    var healthCompletionHandler: ((WorkoutSessionSummary) async -> (calories: Double?, identifier: String?))?

    init(container: ModelContainer) {
        self.container = container
        store = WorkoutStoreActor(modelContainer: container)
    }

    func prepare() async {
        guard !isReady else { return }
        do {
            try await store.seedIfNeeded()
            try await refresh()
            try await publishRoutineProvider()
            await syncCloud()
            isReady = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async throws {
        exercises = try await store.exercises()
        templates = try await store.templates()
        sessions = try await store.sessions()
        activeSession = try await store.activeSession()
        activeLogs = try await store.activeLogs()
    }

    func saveExercise(_ draft: ExerciseDraft) async {
        do {
            _ = try await store.saveExercise(draft)
            try await refresh()
            try await publishRoutineProvider()
            await syncCloud()
        } catch { errorMessage = error.localizedDescription }
    }

    func start(template: WorkoutTemplateSummary?) async {
        do {
            _ = try await store.startSession(templateID: template?.id, name: template?.name ?? "Quick Workout")
            try await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleSession() async {
        guard let session = activeSession else { return }
        do {
            if session.state == .active { try await store.pauseSession(id: session.id) }
            else { try await store.resumeSession(id: session.id) }
            try await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func completeSession(actualCalories: Double? = nil, healthKitID: String? = nil) async {
        guard let session = activeSession else { return }
        do {
            let estimatedSession = try await store.updateEstimate(id: session.id) ?? session
            let healthResult = if let healthCompletionHandler {
                await healthCompletionHandler(estimatedSession)
            } else {
                (calories: actualCalories, identifier: healthKitID)
            }
            completedRecap = try await store.completeSession(id: session.id, actualCalories: healthResult.calories, healthKitID: healthResult.identifier)
            if let routineInvocationID, let integration = try? RoutineIntegrationStore() {
                _ = try? await integration.updateInvocation(id: routineInvocationID, state: .completed, message: "Workout completed")
                self.routineInvocationID = nil
            }
            try await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func setCompletedSets(logID: UUID, count: Int) async {
        do {
            try await store.setCompletedSets(logID: logID, count: count)
            try await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func dismissRecap() { completedRecap = nil }

    func handleRoutineInvocation(_ url: URL) async -> RoutineInvocation? {
        do {
            let integration = try RoutineIntegrationStore()
            let id = try RoutineIntegrationStore.invocationID(from: url)
            guard var invocation = try await integration.invocation(id: id), invocation.providerID == WorkoutRoutineProvider.providerID else { return nil }
            invocation = try await integration.updateInvocation(id: id, state: .running, message: "Workout started")
            switch invocation.actionID {
            case "start-today":
                routineInvocationID = invocation.id
                await start(template: templateForToday() ?? templates.first)
            case "start-stretch":
                routineInvocationID = invocation.id
                let stretch = templates.first { $0.name.localizedCaseInsensitiveContains("stretch") }
                await start(template: stretch)
            case "open-exercise":
                pendingExerciseID = invocation.configuration["exerciseID"].flatMap(UUID.init(uuidString:))
                invocation = try await integration.updateInvocation(id: id, state: .completed, message: "Exercise opened")
            default: return nil
            }
            return invocation
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func templateForToday(date: Date = .now) -> WorkoutTemplateSummary? {
        let weekday = Calendar.current.component(.weekday, from: date)
        return templates.first { $0.scheduledWeekdays.contains(weekday) }
    }

    private func publishRoutineProvider() async throws {
        guard let integration = try? RoutineIntegrationStore() else { return }
        try await WorkoutRoutineProvider.publish(store: integration, todayTemplate: templateForToday(), exercises: exercises)
    }

    func syncCloud() async {
        guard ProductivityCloudSyncEngine.isCloudKitAvailable else {
            cloudStatus = "Local only"
            return
        }
        do {
            let engine = cloudSync ?? makeCloudSync()
            cloudSync = engine
            try await engine.queue(store.cloudRecords())
            try await engine.synchronize()
            cloudStatus = "Up to date"
            try await refresh()
        } catch {
            cloudStatus = "Local only"
        }
    }

    private func makeCloudSync() -> ProductivityCloudSyncEngine {
        let store = store
        return ProductivityCloudSyncEngine(
            containerIdentifier: "iCloud.com.productivitysuite.workouts",
            zoneName: "Workouts",
            stateURL: URL.applicationSupportDirectory.appending(path: "Workouts/CloudKit/state.json"),
            onRemoteChanges: { records, deletions in
                try? await store.applyCloudRecords(records, deletions: deletions)
            }
        )
    }
}
