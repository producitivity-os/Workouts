import ProductivityUI
import SwiftUI

struct WorkoutSettingsView: View {
    @Environment(WorkoutsAppState.self) private var state
    @State private var bodyMass = 70.0
    @State private var healthEnabled = false
    @State private var saved = false

    var body: some View {
        Form {
            Section("Energy estimates") {
                TextField("Body mass (kg)", value: $bodyMass, format: .number)
                Text("Your weight is used with each exercise's MET value to estimate calories.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Apple Health") {
                Toggle("Sync completed workouts", isOn: $healthEnabled)
                Text("HealthKit is available on iPhone. The Mac keeps estimates locally.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Cloud sync") {
                LabeledContent("Exercises and templates", value: state.cloudStatus)
                Button("Sync Now") { Task { await state.syncCloud() } }
            }
            Button(saved ? "Saved" : "Save") {
                Task {
                    try? await state.store.updatePreferences(bodyMass: bodyMass, healthEnabled: healthEnabled)
                    saved = true
                }
            }.buttonStyle(.borderedProminent)
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 300)
        .task {
            if let preferences = try? await state.store.preferences() {
                bodyMass = preferences.bodyMass
                healthEnabled = preferences.healthEnabled
            }
        }
    }
}
