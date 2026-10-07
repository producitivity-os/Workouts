import Foundation
import ProductivityUI
import SwiftUI

struct WorkoutTodayView: View {
    @Environment(WorkoutsAppState.self) private var state

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ProductivitySpacing.section) {
                ProductivityPageHeader("Today", eyebrow: "Workouts")
                if let session = state.activeSession {
                    ProductivitySectionCard("Current workout") {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.name).font(.title2.bold())
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    Text(elapsed(session, at: context.date).formattedDuration)
                                        .font(.system(.title, design: .rounded).monospacedDigit())
                                }
                            }
                            Spacer()
                            Button(session.state == .active ? "Pause" : "Resume") { Task { await state.toggleSession() } }
                            Button("Finish") { Task { await state.completeSession() } }.buttonStyle(.borderedProminent)
                        }
                    }
                } else if let template = state.templateForToday() ?? state.templates.first {
                    ProductivitySectionCard("Scheduled") {
                        Text(template.name).font(.title2.bold())
                        Text(template.exerciseNames.joined(separator: " • ")).foregroundStyle(.secondary)
                        Button("Start Workout") { Task { await state.start(template: template) } }.buttonStyle(.borderedProminent)
                    }
                } else {
                    ProductivityEmptyState(icon: .dumbbell, title: "No workout scheduled", message: "Create a workout template or start a quick workout.")
                    Button("Start Quick Workout") { Task { await state.start(template: nil) } }
                }
                HStack {
                    ProductivityMetricCard(title: "Exercises", value: "\(state.exercises.count)", tint: .blue)
                    ProductivityMetricCard(title: "Completed", value: "\(state.sessions.filter { $0.state == .completed }.count)", tint: .green)
                }
            }.padding(ProductivitySpacing.page)
        }
    }

    private func elapsed(_ session: WorkoutSessionSummary, at date: Date) -> Double {
        session.elapsedSeconds + (session.state == .active ? max(0, date.timeIntervalSince(session.activeSince ?? date)) : 0)
    }
}

private extension Double {
    var formattedDuration: String {
        let value = max(0, Int(self.rounded()))
        return String(format: "%02d:%02d:%02d", value / 3_600, value / 60 % 60, value % 60)
    }
}

struct ExerciseLibraryView: View {
    @Environment(WorkoutsAppState.self) private var state
    @State private var editingID: UUID?
    @State private var showsEditor = false
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            ProductivityPageHeader("Exercises", eyebrow: "Library", actionTitle: "Add Exercise") {
                editingID = nil
                showsEditor = true
            }.padding(ProductivitySpacing.page)
            List(filtered) { exercise in
                Button {
                    editingID = exercise.id
                    showsEditor = true
                } label: {
                    HStack(spacing: 12) {
                        LucideIcon(name: icon(exercise.kind), size: 22).foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(exercise.name).font(.headline)
                            Text(exercise.details.isEmpty ? exercise.kind.title : exercise.details).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        if exercise.hasAnimation { ProductivityStatusBadge("Animation", tint: .purple) }
                        ProductivityStatusBadge(exercise.kind.title)
                    }.padding(.vertical, 5)
                }.buttonStyle(.plain)
            }
            .searchable(text: $search)
            .overlay { if filtered.isEmpty { ProductivityEmptyState(icon: .dumbbell, title: "No exercises", message: "Add an exercise to begin building workouts.") } }
        }
        .sheet(isPresented: $showsEditor) { ExerciseEditorView(exerciseID: editingID).environment(state) }
    }

    private var filtered: [ExerciseSummary] {
        search.isEmpty ? state.exercises : state.exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private func icon(_ kind: ExerciseKind) -> LucideIconName {
        switch kind { case .distance: .foot; case .repetitions: .dumbbell; case .timed: .timer }
    }
}

struct WorkoutTemplatesView: View {
    @Environment(WorkoutsAppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            ProductivityPageHeader("Workouts", eyebrow: "Templates").padding(ProductivitySpacing.page)
            List(state.templates) { template in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(template.name).font(.headline)
                        Spacer()
                        Button("Start") { Task { await state.start(template: template) } }
                    }
                    Text(template.exerciseNames.joined(separator: " • ")).foregroundStyle(.secondary)
                    if !template.notes.isEmpty { Text(template.notes).font(.caption).foregroundStyle(.secondary) }
                }.padding(.vertical, 6)
            }
            .overlay { if state.templates.isEmpty { ProductivityEmptyState(icon: .listOrdered, title: "No workouts", message: "Workout templates combine exercises into a repeatable session.") } }
        }
    }
}

struct WorkoutHistoryView: View {
    @Environment(WorkoutsAppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            ProductivityPageHeader("History", eyebrow: "Progress").padding(ProductivitySpacing.page)
            List(state.sessions) { session in
                HStack {
                    VStack(alignment: .leading) {
                        Text(session.name).font(.headline)
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(session.elapsedSeconds.formattedDuration).monospacedDigit()
                    ProductivityStatusBadge(session.state.rawValue.capitalized, tint: session.state == .completed ? .green : .orange)
                }.padding(.vertical, 4)
            }
            .overlay { if state.sessions.isEmpty { ProductivityEmptyState(icon: .activity, title: "No history", message: "Completed workouts will appear here.") } }
        }
    }
}
