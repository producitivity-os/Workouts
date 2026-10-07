import Testing
@testable import WorkoutsIOS

@Test func healthAccessStateHasUnavailableFallback() {
    #expect(WorkoutHealthAccessState.allCasesForTesting.contains(.unavailable))
}

private extension WorkoutHealthAccessState {
    static var allCasesForTesting: [Self] { [.disabled, .unavailable, .ready, .denied, .failed] }
}
