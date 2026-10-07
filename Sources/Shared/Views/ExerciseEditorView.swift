import ProductivityUI
import SwiftUI
import UniformTypeIdentifiers

struct ExerciseEditorView: View {
    @Environment(WorkoutsAppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let exerciseID: UUID?
    @State private var draft = ExerciseDraft()
    @State private var isImporting = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $draft.name)
                    TextField("Description", text: $draft.details, axis: .vertical)
                    Picker("Type", selection: $draft.kind) {
                        ForEach(ExerciseKind.allCases) { Text($0.title).tag($0) }
                    }
                    LabeledContent("Intensity") {
                        HStack {
                            Slider(value: $draft.metValue, in: 1...20, step: 0.1)
                            Text(draft.metValue.formatted(.number.precision(.fractionLength(1)))).monospacedDigit()
                        }.frame(maxWidth: 260)
                    }
                }
                typeSection
                Section("Instructions") {
                    ForEach(draft.steps.indices, id: \.self) { index in
                        HStack {
                            TextField("Step \(index + 1)", text: $draft.steps[index])
                            Button(role: .destructive) { draft.steps.remove(at: index) } label: {
                                LucideIcon(name: .trash)
                            }.buttonStyle(.plain)
                        }
                    }
                    Button("Add Step", systemImage: "plus") { draft.steps.append("") }
                }
                Section("Animation") {
                    if let data = draft.mediaData, let mime = draft.mediaMIMEType {
                        ExerciseMediaView(data: data, mimeType: mime).frame(height: 180)
                        Text(draft.mediaName ?? "Animation").foregroundStyle(.secondary)
                    }
                    Button("Import GIF or Video") { isImporting = true }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(exerciseID == nil ? "New Exercise" : "Edit Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await state.saveExercise(draft); dismiss() }
                    }.disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay { if isLoading { ProgressView() } }
            .task {
                guard let exerciseID else { draft.steps = [""]; return }
                isLoading = true
                if let loaded = try? await state.store.exerciseDraft(id: exerciseID) { draft = loaded }
                isLoading = false
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.gif, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false
            ) { result in
                guard case let .success(urls) = result, let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { return }
                draft.mediaName = url.lastPathComponent
                draft.mediaMIMEType = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.preferredMIMEType ?? "image/gif"
                draft.mediaData = data
            }
        }
        .frame(minWidth: 520, minHeight: 600)
    }

    @ViewBuilder private var typeSection: some View {
        switch draft.kind {
        case .distance:
            Section("Distance defaults") {
                Picker("Activity", selection: $draft.distanceActivity) {
                    ForEach(DistanceActivity.allCases) { Text($0.title).tag($0) }
                }
                TextField("Distance in metres", value: $draft.distanceMeters, format: .number)
                TextField("Duration in seconds", value: $draft.durationSeconds, format: .number)
                Toggle("Indoor", isOn: $draft.isIndoor)
            }
        case .repetitions:
            Section("Repetition defaults") {
                Picker("Style", selection: $draft.repetitionStyle) {
                    ForEach(RepetitionStyle.allCases) { Text($0.title).tag($0) }
                }
                Stepper("Sets: \(draft.sets)", value: $draft.sets, in: 1...100)
                Stepper("Repetitions: \(draft.repetitions)", value: $draft.repetitions, in: 1...1_000)
                if draft.repetitionStyle == .weighted {
                    TextField("Weight in kilograms", value: $draft.weightKilograms, format: .number)
                }
                if draft.repetitionStyle == .resistance {
                    TextField("Resistance", text: $draft.resistanceLabel)
                }
                Toggle("Unilateral", isOn: $draft.isUnilateral)
            }
        case .timed:
            Section("Timing defaults") {
                Picker("Activity", selection: $draft.timedActivity) {
                    ForEach(TimedActivity.allCases) { Text($0.title).tag($0) }
                }
                TextField("Duration in seconds", value: $draft.durationSeconds, format: .number)
            }
        }
    }
}
