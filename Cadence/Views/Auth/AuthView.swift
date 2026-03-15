import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @State private var viewModel = AuthViewModel()

    private let ctaHeight: CGFloat = 50
    private let ctaCornerRadius: CGFloat = 14
    private let inputCornerRadius: CGFloat = 10
    private let screenMargin: CGFloat = 16
    private let disabledOpacity: Double = 0.4
    private let sectionSpacing: CGFloat = 24
    private let inputHeight: CGFloat = 50

    var body: some View {
        ZStack {
            Color("CadenceBackground")
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: sectionSpacing) {
                    headerSection
                    socialAuthSection
                    dividerSection
                    emailPasswordSection
                    forgotPasswordSection
                    continueSection
                    modeToggleSection
                }
                .padding(.horizontal, screenMargin)
                .padding(.top, 60)
                .padding(.bottom, 40)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Cadence")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundStyle(Color("CadenceTextPrimary"))

            Text("Track your cycle. Share what matters.")
                .font(.subheadline)
                .foregroundStyle(Color("CadenceTextSecondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private var socialAuthSection: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                let hashedNonce = viewModel.generateNonce()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce
            } onCompletion: { result in
                Task { await viewModel.handleAppleSignIn(result: result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: ctaHeight)
            .clipShape(RoundedRectangle(cornerRadius: ctaCornerRadius))

            Button {
                Task { await viewModel.signInWithGoogle() }
            } label: {
                Text("Sign in with Google")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("CadenceTextPrimary"))
                    .frame(maxWidth: .infinity)
                    .frame(height: ctaHeight)
                    .background(Color("CadenceCard"))
                    .clipShape(RoundedRectangle(cornerRadius: ctaCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: ctaCornerRadius)
                            .stroke(Color("CadenceBorder"), lineWidth: 1)
                    )
            }
            .frame(minHeight: 44)
        }
    }

    private var dividerSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color("CadenceBorder"))
                .frame(height: 1)
            Text("or")
                .font(.caption)
                .foregroundStyle(Color("CadenceTextSecondary"))
            Rectangle()
                .fill(Color("CadenceBorder"))
                .frame(height: 1)
        }
    }

    private var emailPasswordSection: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $viewModel.email)
                .font(.body)
                .foregroundStyle(Color("CadenceTextPrimary"))
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 16)
                .frame(height: inputHeight)
                .background(Color("CadenceCard"))
                .clipShape(RoundedRectangle(cornerRadius: inputCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: inputCornerRadius)
                        .stroke(Color("CadenceBorder"), lineWidth: 1)
                )
                .onChange(of: viewModel.email) { viewModel.clearError() }

            passwordField
        }
    }

    private var passwordField: some View {
        HStack(spacing: 8) {
            Group {
                if viewModel.isPasswordVisible {
                    TextField("Password", text: $viewModel.password)
                } else {
                    SecureField("Password", text: $viewModel.password)
                }
            }
            .font(.body)
            .foregroundStyle(Color("CadenceTextPrimary"))
            .textContentType(.password)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button {
                viewModel.isPasswordVisible.toggle()
            } label: {
                Text(viewModel.isPasswordVisible ? "Hide" : "Show")
                    .font(.callout)
                    .foregroundStyle(Color("CadenceTerracotta"))
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 16)
        .frame(height: inputHeight)
        .background(Color("CadenceCard"))
        .clipShape(RoundedRectangle(cornerRadius: inputCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: inputCornerRadius)
                .stroke(Color("CadenceBorder"), lineWidth: 1)
        )
        .onChange(of: viewModel.password) { viewModel.clearError() }
    }

    private var forgotPasswordSection: some View {
        HStack {
            Spacer()
            Button {
                Task { await viewModel.forgotPassword() }
            } label: {
                Text("Forgot password?")
                    .font(.footnote)
                    .foregroundStyle(Color("CadenceTerracotta"))
            }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(!viewModel.isForgotPasswordEnabled)
            .opacity(viewModel.isForgotPasswordEnabled ? 1.0 : disabledOpacity)
        }
    }

    private var continueSection: some View {
        VStack(spacing: 12) {
            if viewModel.showForgotPasswordConfirmation {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.fill")
                    Text("Check your email for a reset link.")
                }
                .font(.footnote)
                .foregroundStyle(Color("CadenceTextSecondary"))
            } else {
                Button {
                    Task { await viewModel.submitEmailPassword() }
                } label: {
                    ZStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(viewModel.continueButtonLabel)
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
            }

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

    private var modeToggleSection: some View {
        HStack(spacing: 4) {
            Text(viewModel.modeTogglePrefix)
                .font(.footnote)
                .foregroundStyle(Color("CadenceTextSecondary"))
            Button {
                viewModel.toggleMode()
            } label: {
                Text(viewModel.modeToggleAction)
                    .font(.footnote)
                    .foregroundStyle(Color("CadenceTerracotta"))
            }
            .frame(minHeight: 44)
        }
    }
}
