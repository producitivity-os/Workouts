import Foundation

enum WorkoutCalorieEstimator {
    static func estimate(met: Double, bodyMassKilograms: Double, durationSeconds: Double) -> Double {
        guard met > 0, bodyMassKilograms > 0, durationSeconds > 0 else { return 0 }
        let minutes = durationSeconds / 60
        return met * 3.5 * bodyMassKilograms / 200 * minutes
    }

    static func preferred(estimated: Double, healthKitActual: Double?) -> Double {
        guard let healthKitActual, healthKitActual >= 0 else { return estimated }
        return healthKitActual
    }
}
