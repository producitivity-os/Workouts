import SwiftData
import SwiftUI

@main
struct WorkoutsIOSApp: App {
    private let container: ModelContainer
    @State private var state: WorkoutsAppState
    @State private var health = WorkoutHealthKitManager()

    init() {
        do {
            let schema = Schema(WorkoutSchemaV1.models)
            let configuration = ModelConfiguration("Workouts", schema: schema, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, migrationPlan: WorkoutMigrationPlan.self, configurations: [configuration])
            self.container = container
            _state = State(initialValue: WorkoutsAppState(container: container))
        } catch {
            fatalError("Workouts could not open its store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            WorkoutsIOSRootView()
                .environment(state)
                .environment(health)
                .modelContainer(container)
                .task {
                    await state.prepare()
                    state.healthCompletionHandler = { session in
                        do { return try await health.saveCompletedSession(session) }
                        catch { return (nil, nil) }
                    }
                }
                .onOpenURL { url in Task { _ = await state.handleRoutineInvocation(url) } }
        }
    }
}
