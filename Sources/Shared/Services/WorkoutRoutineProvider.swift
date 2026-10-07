import Foundation
import ProductivityRoutineKit

enum WorkoutRoutineProvider {
    static let providerID = "com.productivitysuite.workouts"

    static var manifest: RoutineProviderManifest {
        RoutineProviderManifest(
            id: providerID,
            displayName: "Workouts",
            urlScheme: "productivity-workouts",
            iconName: "dumbbell",
            actions: [
                RoutineActionDescriptor(id: "start-today", title: "Start Today's Workout", subtitle: "Begin the scheduled workout", iconName: "play", tintHex: "#3B82F6"),
                RoutineActionDescriptor(id: "start-stretch", title: "Start Stretch Routine", subtitle: "Begin today's stretch session", iconName: "activity", tintHex: "#14B8A6"),
                RoutineActionDescriptor(
                    id: "open-exercise",
                    title: "Open Exercise",
                    subtitle: "Open a selected exercise",
                    iconName: "dumbbell",
                    tintHex: "#8B5CF6",
                    configurationFields: [.init(id: "exerciseID", title: "Exercise", kind: .choice, required: true)]
                )
            ]
        )
    }

    static func publish(
        store: RoutineIntegrationStore,
        todayTemplate: WorkoutTemplateSummary?,
        exercises: [ExerciseSummary]
    ) async throws {
        try await store.publish(manifest)
        if let todayTemplate {
            try await store.publish(RoutineStatusSnapshot(
                id: "workouts.today",
                providerID: providerID,
                actionID: "start-today",
                title: todayTemplate.name,
                subtitle: todayTemplate.exerciseNames.joined(separator: " • "),
                metadata: ["templateID": todayTemplate.id.uuidString]
            ))
        }
        for exercise in exercises {
            try await store.publish(RoutineStatusSnapshot(
                id: "workouts.exercise.\(exercise.id.uuidString)",
                providerID: providerID,
                actionID: "open-exercise",
                title: exercise.name,
                subtitle: exercise.kind.title,
                metadata: ["exerciseID": exercise.id.uuidString]
            ))
        }
    }
}
