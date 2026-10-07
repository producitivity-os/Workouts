import ProductivityUI
import SwiftUI

private enum WorkoutsDestination: String, CaseIterable, Identifiable {
    case today, exercises, workouts, history
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: LucideIconName {
        switch self {
        case .today: .calendar
        case .exercises: .dumbbell
        case .workouts: .listOrdered
        case .history: .activity
        }
    }
}

struct WorkoutsMacRootView: View {
    @Environment(WorkoutsAppState.self) private var state
    @State private var selection = WorkoutsDestination.today

    var body: some View {
        NavigationSplitView {
            List(WorkoutsDestination.allCases, selection: $selection) { destination in
                Label { Text(destination.title) } icon: { LucideIcon(name: destination.icon) }
                    .tag(destination)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            ProductivityAsyncState(isLoading: !state.isReady && state.errorMessage == nil, error: state.errorMessage) {
                switch selection {
                case .today: WorkoutTodayView()
                case .exercises: ExerciseLibraryView()
                case .workouts: WorkoutTemplatesView()
                case .history: WorkoutHistoryView()
                }
            }
        }
        .frame(minWidth: 700, minHeight: 520)
        .task { await state.prepare() }
        .onOpenURL { url in Task { _ = await state.handleRoutineInvocation(url) } }
    }
}
