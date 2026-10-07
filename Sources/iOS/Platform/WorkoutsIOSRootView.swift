import ProductivityUI
import SwiftUI

struct WorkoutsIOSRootView: View {
    @Environment(WorkoutsAppState.self) private var state

    var body: some View {
        ProductivityAsyncState(isLoading: !state.isReady && state.errorMessage == nil, error: state.errorMessage) {
            TabView {
                NavigationStack { WorkoutTodayView() }
                    .tabItem { Label("Today", systemImage: "calendar") }
                NavigationStack { ExerciseLibraryView() }
                    .tabItem { Label("Exercises", systemImage: "dumbbell") }
                NavigationStack { WorkoutTemplatesView() }
                    .tabItem { Label("Workouts", systemImage: "list.bullet.rectangle") }
                NavigationStack { WorkoutHistoryView() }
                    .tabItem { Label("History", systemImage: "chart.xyaxis.line") }
                NavigationStack { WorkoutSettingsView() }
                    .tabItem { Label("Settings", systemImage: "gearshape") }
            }
        }
    }
}
