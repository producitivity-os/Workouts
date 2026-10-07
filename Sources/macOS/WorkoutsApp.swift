import SwiftData
import SwiftUI

@main
struct WorkoutsApp: App {
    private let container: ModelContainer
    @State private var state: WorkoutsAppState

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
            WorkoutsMacRootView().environment(state).modelContainer(container)
        }
        .defaultSize(width: 920, height: 650)

        Settings { WorkoutSettingsView().environment(state).modelContainer(container) }
    }
}
