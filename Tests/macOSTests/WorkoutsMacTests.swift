import Testing
@testable import Workouts

@Test func exerciseKindsHaveTitles() {
    #expect(ExerciseKind.allCases.allSatisfy { !$0.title.isEmpty })
}
