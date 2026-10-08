import Foundation
import ProductivityUI
import SwiftUI

struct WorkoutTodayView: View {
    @Environment(WorkoutsAppState.self) private var state
    @State private var showsExerciseEditor = false

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
                    if !state.activeLogs.isEmpty {
                        WorkoutZoningBar(
                            workoutName: session.name,
                            completedSets: state.activeLogs.reduce(0) { $0 + $1.completedSets },
                            plannedSets: state.activeLogs.reduce(0) { $0 + $1.plannedSets }
                        )
                        ForEach(state.activeLogs) { log in
                            WorkoutSetsCard(exercise: log) { count in Task { await state.setCompletedSets(logID: log.id, count: count) } }
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
        .overlay(alignment: .bottomTrailing) {
            MorphingActionMenu(actions: [
                .init(id: "quick", icon: "bolt.fill", title: "Quick Workout"),
                .init(id: "exercise", icon: "dumbbell.fill", title: "New Exercise")
            ]) { item in
                if item.id == "quick" { Task { await state.start(template: nil) } }
                else { showsExerciseEditor = true }
            }
            .padding(18)
        }
        .sheet(isPresented: $showsExerciseEditor) { ExerciseEditorView(exerciseID: nil).environment(state) }
        .sheet(item: Binding(get: { state.completedRecap }, set: { if $0 == nil { state.dismissRecap() } })) { session in
            SessionCompleteRecap(session: session) { state.dismissRecap() }
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
        ScrollView {
            VStack(alignment: .leading, spacing: ProductivitySpacing.section) {
                ProductivityPageHeader("History", eyebrow: "Progress")
                if state.sessions.isEmpty {
                    ProductivityEmptyState(icon: .activity, title: "No history", message: "Completed workouts will appear here.")
                } else {
                    CoreActivityMetrics(metrics: historyMetrics)
                    ProductivitySectionCard("Workout duration") {
                        DynamicRangeBarChart(data: chartData, range: .week, barsColor: .purple, unit: "m").frame(height: 180)
                    }
                    ForEach(state.sessions) { WorkoutExpandedCard(workout: $0) }
                }
            }.padding(ProductivitySpacing.page)
        }
    }

    private var chartData: [DynamicBarChartData] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: .now)) ?? .now
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let seconds = state.sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }.reduce(0) { $0 + $1.elapsedSeconds }
            return DynamicBarChartData(date: date, value: seconds / 60)
        }
    }

    private var historyMetrics: [CoreActivityMetric] {
        let completed = state.sessions.filter { $0.state == .completed }
        let weekly = completed.filter { $0.startedAt >= Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now }
        let minutes = weekly.reduce(0) { $0 + $1.elapsedSeconds } / 60
        let calories = weekly.reduce(0) { $0 + ($1.actualCalories ?? $1.estimatedCalories) }
        return [
            .init(label: "Workouts", value: min(100, Double(weekly.count) / 4 * 100), targetZone: 75...100, ramp: [.blue, .cyan, .blue]),
            .init(label: "Minutes", value: min(100, minutes / 150 * 100), targetZone: 75...100, ramp: [.green, .mint, .green]),
            .init(label: "Energy", value: min(100, calories / 1_500 * 100), ramp: [.orange, .yellow, .orange])
        ]
    }
}
