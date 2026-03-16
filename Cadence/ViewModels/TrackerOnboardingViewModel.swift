import Foundation
import Observation

@Observable
@MainActor
final class TrackerOnboardingViewModel {
    var lastPeriodDate: Date = .now
    var averageCycleLength: Int = 28
    var averagePeriodLength: Int = 5
    var goalMode: GoalMode?
    var isLoading = false
    var errorMessage: String?

    let minimumCycleLength = 15
    let maximumCycleLength = 60
    let minimumPeriodLength = 1

    var maximumPeriodLength: Int {
        averageCycleLength - 1
    }

    var isFormValid: Bool {
        goalMode != nil
    }

    var earliestAllowedDate: Date {
        Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .now
    }

    func adjustPeriodLengthIfNeeded() {
        let cap = averageCycleLength - 1
        if averagePeriodLength > cap {
            averagePeriodLength = cap
        }
    }

    func submit(
        userId: UUID,
        onComplete: @escaping () -> Void,
        performUpsert: ((CycleProfile) async throws -> Void)? = nil
    ) async {
        guard isFormValid, let selectedGoalMode = goalMode else { return }
        isLoading = true
        errorMessage = nil

        let profile = CycleProfile(
            userId: userId,
            averageCycleLength: averageCycleLength,
            averagePeriodLength: averagePeriodLength,
            goalMode: selectedGoalMode,
            predictionsEnabled: true
        )

        do {
            if let performUpsert {
                try await performUpsert(profile)
            } else {
                try await supabase
                    .from("cycle_profiles")
                    .upsert(profile, onConflict: "user_id")
                    .execute()
            }
            onComplete()
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isLoading = false
    }
}
