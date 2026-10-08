import Foundation
import ProductivityUI
import SwiftUI

struct ActivityWidgetCard: View {
    let icon: String
    let title: String
    let date: Date
    let color: Color
    let primaryMetric: String
    let secondaryMetric: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(color).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                HStack(spacing: 8) {
                    Text(primaryMetric)
                    if let secondaryMetric { Divider().frame(height: 11); Text(secondaryMetric) }
                }.font(.subheadline.weight(.medium))
            }
            Spacer()
            Text(formattedDate)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: ProductivityRadius.card))
    }

    private var formattedDate: String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct WorkoutExpandedCard: View {
    let workout: WorkoutSessionSummary
    @State private var isExpanded = false

    private var effort: Double {
        min(100, max(0, workout.elapsedSeconds / 36 + (workout.actualCalories ?? workout.estimatedCalories) / 8))
    }

    var body: some View {
        VStack(spacing: 10) {
            ActivityWidgetCard(
                icon: "figure.strengthtraining.traditional",
                title: workout.name,
                date: workout.startedAt,
                color: workout.state == .completed ? .green : .orange,
                primaryMetric: workout.elapsedSeconds.formattedWorkoutDuration,
                secondaryMetric: "\(Int((workout.actualCalories ?? workout.estimatedCalories).rounded())) kcal"
            )
            if isExpanded {
                HStack(spacing: 8) {
                    info("Time", workout.elapsedSeconds.formattedWorkoutDuration)
                    info("Calories", "\(Int((workout.actualCalories ?? workout.estimatedCalories).rounded()))")
                    VStack(spacing: 5) {
                        Text("Effort").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 3) {
                            ForEach(0..<4, id: \.self) { index in
                                Capsule().fill(index < Int(ceil(effort / 25)) ? effortColor(index) : Color.secondary.opacity(0.15)).frame(height: 7)
                            }
                        }
                    }.frame(maxWidth: .infinity)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.snappy) { isExpanded.toggle() } }
    }

    private func info(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.headline) }
            .frame(maxWidth: .infinity).padding(8).background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    private func effortColor(_ index: Int) -> Color { [.green, .yellow, .orange, .red][min(index, 3)] }
}

struct WorkoutZoningBar: View {
    let workoutName: String
    let completedSets: Int
    let plannedSets: Int

    private let zoneCounts = [5, 7, 4]
    private var total: Int { zoneCounts.reduce(0, +) }
    private var zone: (String, Color) {
        if completedSets <= zoneCounts[0] { return ("Rest zone", .blue) }
        if completedSets <= zoneCounts[0] + zoneCounts[1] { return ("Growth zone", .green) }
        return ("Focus zone", .yellow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutName.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\(completedSets) of \(plannedSets) sets").font(.headline)
                }
                Spacer(); Text(zone.0).font(.subheadline.weight(.semibold)).foregroundStyle(zone.1)
            }
            HStack(spacing: 3) {
                ForEach(0..<total, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4).fill(color(index).opacity(index < completedSets ? 1 : 0.16)).frame(height: 25)
                }
            }
        }
    }

    private func color(_ index: Int) -> Color {
        if index < zoneCounts[0] { return .blue }
        if index < zoneCounts[0] + zoneCounts[1] { return .green }
        return .yellow
    }
}

struct WorkoutSetsCard: View {
    let exercise: WorkoutExerciseLogSummary
    let setCompletedCount: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(exercise.exerciseName).font(.headline); Spacer(); Text("\(exercise.completedSets)/\(exercise.plannedSets)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            ForEach(0..<exercise.plannedSets, id: \.self) { index in
                HStack(spacing: 10) {
                    Text("\(index + 1)").font(.caption.bold()).frame(width: 28, height: 28).background(index < exercise.completedSets ? Color.green : .secondary.opacity(0.14), in: Circle())
                    if let weight = exercise.weightKilograms { Text("\(weight.formatted()) kg").frame(maxWidth: .infinity, alignment: .leading) }
                    if let repetitions = exercise.repetitions { Text("× \(repetitions) reps").frame(maxWidth: .infinity, alignment: .leading) }
                    if let distance = exercise.distanceMeters {
                        Text(Measurement(value: distance, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road)))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        setCompletedCount(index < exercise.completedSets ? index : index + 1)
                    } label: {
                        Image(systemName: index < exercise.completedSets ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(index < exercise.completedSets ? .green : .secondary)
                    }.buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                if index < exercise.plannedSets - 1 { Divider() }
            }
        }
        .padding(13)
        .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: ProductivityRadius.card))
    }
}

struct WorkoutSummaryGrid: View {
    let session: WorkoutSessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Well done, you completed \(session.name).").font(.largeTitle.bold())
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                ProductivityMetricCard(title: "Duration", value: session.elapsedSeconds.formattedWorkoutDuration, tint: .blue, systemImage: "clock.fill")
                ProductivityMetricCard(title: "Calories", value: "\(Int((session.actualCalories ?? session.estimatedCalories).rounded())) kcal", tint: .orange, systemImage: "flame.fill")
                ProductivityMetricCard(title: "Completed", value: session.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Now", tint: .green, systemImage: "checkmark.circle.fill")
                ProductivityMetricCard(title: "Source", value: session.actualCalories == nil ? "Estimated" : "Apple Health", tint: .purple, systemImage: "heart.fill")
            }
        }
    }
}

struct SessionCompleteRecap: View {
    let session: WorkoutSessionSummary
    let dismiss: () -> Void

    var body: some View {
        ScrollView { WorkoutSummaryGrid(session: session).padding(24) }
            .safeAreaInset(edge: .bottom) { Button("Done", action: dismiss).buttonStyle(.borderedProminent).controlSize(.large).padding() }
            .frame(minWidth: 420, minHeight: 460)
    }
}

extension Double {
    var formattedWorkoutDuration: String {
        let value = max(0, Int(self.rounded()))
        if value >= 3_600 { return String(format: "%dh %02dm", value / 3_600, value / 60 % 60) }
        return String(format: "%dm %02ds", value / 60, value % 60)
    }
}
