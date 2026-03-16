import SwiftUI

struct TrackerOnboardingView: View {
    var onComplete: () -> Void

    @State private var viewModel = TrackerOnboardingViewModel()

    private let ctaHeight: CGFloat = 50
    private let ctaCornerRadius: CGFloat = 14
    private let pillCornerRadius: CGFloat = 12
    private let pillHeight: CGFloat = 44
    private let screenMargin: CGFloat = 16
    private let sectionSpacing: CGFloat = 24
    private let disabledOpacity: Double = 0.4

    var body: some View {
        ZStack {
            Color("CadenceBackground")
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: sectionSpacing) {
                    Text("Set up your cycle")
                        .font(.title2)
                        .foregroundStyle(Color("CadenceTextPrimary"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    lastPeriodSection
                    cycleLengthSection
                    periodLengthSection
                    goalModeSection
                    continueSection
                }
                .padding(.horizontal, screenMargin)
                .padding(.vertical, sectionSpacing)
            }
        }
    }

    private var lastPeriodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When did your last period start?")
                .font(.subheadline)
                .foregroundStyle(Color("CadenceTextPrimary"))

            DatePicker(
                "",
                selection: $viewModel.lastPeriodDate,
                in: viewModel.earliestAllowedDate ... Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
        }
    }

    private var cycleLengthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Average cycle length")
                .font(.subheadline)
                .foregroundStyle(Color("CadenceTextPrimary"))

            Stepper(
                "\(viewModel.averageCycleLength) days",
                value: $viewModel.averageCycleLength,
                in: viewModel.minimumCycleLength ... viewModel.maximumCycleLength
            )
            .onChange(of: viewModel.averageCycleLength) {
                viewModel.adjustPeriodLengthIfNeeded()
            }
        }
    }

    private var periodLengthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Average period length")
                .font(.subheadline)
                .foregroundStyle(Color("CadenceTextPrimary"))

            Stepper(
                "\(viewModel.averagePeriodLength) days",
                value: $viewModel.averagePeriodLength,
                in: viewModel.minimumPeriodLength ... viewModel.maximumPeriodLength
            )
        }
    }

    private var goalModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's your goal?")
                .font(.subheadline)
                .foregroundStyle(Color("CadenceTextPrimary"))

            HStack(spacing: 12) {
                goalPill(title: "Track my cycle", mode: .trackCycle)
                goalPill(title: "Trying to conceive", mode: .tryingToConceive)
            }
        }
    }

    private func goalPill(title: String, mode: GoalMode) -> some View {
        let isSelected = viewModel.goalMode == mode
        return Button {
            viewModel.goalMode = mode
        } label: {
            Text(title)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(
                    isSelected
                        ? Color("CadenceTextOnAccent")
                        : Color("CadenceTextPrimary")
                )
                .frame(maxWidth: .infinity)
                .frame(height: pillHeight)
                .background(
                    isSelected
                        ? Color("CadenceTerracotta")
                        : Color("CadenceCard")
                )
                .clipShape(RoundedRectangle(cornerRadius: pillCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: pillCornerRadius)
                        .stroke(
                            isSelected ? Color.clear : Color("CadenceBorder"),
                            lineWidth: 1
                        )
                )
        }
        .frame(minHeight: 44)
    }

    private var continueSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    guard let session = try? await supabase.auth.session else { return }
                    await viewModel.submit(userId: session.user.id, onComplete: onComplete)
                }
            } label: {
                ZStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color("CadenceTextOnAccent"))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: ctaHeight)
                .background(Color("CadenceTerracotta"))
                .clipShape(RoundedRectangle(cornerRadius: ctaCornerRadius))
            }
            .disabled(!viewModel.isFormValid || viewModel.isLoading)
            .opacity(viewModel.isFormValid ? 1.0 : disabledOpacity)

            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                }
                .font(.footnote)
                .foregroundStyle(Color("CadenceTextSecondary"))
            }
        }
    }
}
