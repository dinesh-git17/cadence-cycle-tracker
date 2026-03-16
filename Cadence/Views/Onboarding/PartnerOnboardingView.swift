import SwiftUI

struct PartnerOnboardingView: View {
    var onComplete: () -> Void

    @State private var viewModel = PartnerOnboardingViewModel()

    private let ctaHeight: CGFloat = 50
    private let ctaCornerRadius: CGFloat = 14
    private let inputCornerRadius: CGFloat = 10
    private let screenMargin: CGFloat = 16
    private let sectionSpacing: CGFloat = 24
    private let errorAreaHeight: CGFloat = 20
    private let disabledOpacity: Double = 0.4

    var body: some View {
        ZStack {
            Color("CadenceBackground")
                .ignoresSafeArea()

            VStack(spacing: sectionSpacing) {
                Spacer()

                headerSection
                codeInputSection
                continueSection
                errorSection

                Spacer()
            }
            .padding(.horizontal, screenMargin)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Enter your invite code")
                .font(.title2)
                .foregroundStyle(Color("CadenceTextPrimary"))

            Text("Your partner shared a 6-digit code with you. Enter it below to connect.")
                .font(.subheadline)
                .foregroundStyle(Color("CadenceTextSecondary"))
                .multilineTextAlignment(.center)
        }
    }

    private var codeInputSection: some View {
        TextField("000000", text: $viewModel.inviteCode)
            .font(.body)
            .foregroundStyle(Color("CadenceTextPrimary"))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(height: ctaHeight)
            .background(Color("CadenceCard"))
            .clipShape(RoundedRectangle(cornerRadius: inputCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: inputCornerRadius)
                    .stroke(Color("CadenceBorder"), lineWidth: 1)
            )
            .onChange(of: viewModel.inviteCode) { _, newValue in
                viewModel.sanitizeInput(newValue)
                viewModel.clearError()
            }
    }

    private var continueSection: some View {
        Button {
            Task {
                await viewModel.validateCode(onSuccess: onComplete)
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
        .disabled(!viewModel.isCodeComplete || viewModel.isLoading)
        .opacity(viewModel.isCodeComplete ? 1.0 : disabledOpacity)
    }

    private var errorSection: some View {
        Group {
            if viewModel.shouldShowError, let message = viewModel.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(message)
                }
                .font(.footnote)
                .foregroundStyle(Color("CadenceTextSecondary"))
            } else {
                Color.clear
                    .frame(height: errorAreaHeight)
            }
        }
    }
}
