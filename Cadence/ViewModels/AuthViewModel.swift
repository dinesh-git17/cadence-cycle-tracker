import Auth
import AuthenticationServices
import CryptoKit
import Foundation
import Observation

protocol AuthServiceProtocol: Sendable {
    func signUp(email: String, password: String) async throws -> Session
    func signIn(email: String, password: String) async throws -> Session
    func signInWithApple(idToken: String, nonce: String) async throws -> Session
    func signInWithGoogle(redirectTo: URL) async throws
    func resetPassword(email: String) async throws
    func updateUserFullName(_ fullName: String) async throws
}

struct SupabaseAuthService: AuthServiceProtocol {
    func signUp(email: String, password: String) async throws -> Session {
        try await supabase.auth.signUp(email: email, password: password).session
            ?? { throw AuthError.sessionMissing }()
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func signInWithGoogle(redirectTo: URL) async throws {
        try await supabase.auth.signInWithOAuth(provider: .google, redirectTo: redirectTo)
    }

    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }

    func updateUserFullName(_ fullName: String) async throws {
        try await supabase.auth.update(user: .init(data: ["full_name": .string(fullName)]))
    }
}

enum AuthError: Error {
    case sessionMissing
    case appleSignInFailed(String)
    case cancelled
}

enum AuthMode {
    case signUp
    case signIn
}

@Observable
@MainActor
final class AuthViewModel {
    var email = ""
    var password = ""
    var isPasswordVisible = false
    var mode: AuthMode = .signUp
    var isLoading = false
    var errorMessage: String?
    var showForgotPasswordConfirmation = false

    var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && Self.emailPattern.firstMatch(
            in: email, range: NSRange(email.startIndex..., in: email)
        ) != nil && password.count >= minimumPasswordLength
    }

    var isForgotPasswordEnabled: Bool {
        !email.isEmpty && Self.emailPattern.firstMatch(
            in: email, range: NSRange(email.startIndex..., in: email)
        ) != nil
    }

    var continueButtonLabel: String {
        mode == .signUp ? "Continue" : "Sign in"
    }

    var modeTogglePrefix: String {
        mode == .signUp ? "Already have an account?" : "New here?"
    }

    var modeToggleAction: String {
        mode == .signUp ? "Sign in" : "Create account"
    }

    private let authService: AuthServiceProtocol
    private static let emailPattern: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(pattern: "[^@]+@[^.]+\\..+") else {
            fatalError("Invalid email regex pattern")
        }
        return regex
    }()

    private let minimumPasswordLength = 8
    private var currentNonce: String?

    init(authService: AuthServiceProtocol = SupabaseAuthService()) {
        self.authService = authService
    }

    func toggleMode() {
        mode = mode == .signUp ? .signIn : .signUp
        clearError()
    }

    func clearError() {
        errorMessage = nil
    }

    func submitEmailPassword() async {
        guard isFormValid else { return }
        isLoading = true
        errorMessage = nil

        do {
            switch mode {
            case .signUp:
                _ = try await authService.signUp(email: email, password: password)
            case .signIn:
                _ = try await authService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = mapError(error)
        }

        isLoading = false
    }

    func forgotPassword() async {
        guard isForgotPasswordEnabled else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await authService.resetPassword(email: email)
            showForgotPasswordConfirmation = true
        } catch {
            errorMessage = mapError(error)
        }

        isLoading = false
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let idToken = String(data: identityTokenData, encoding: .utf8),
                  let nonce = currentNonce
            else {
                errorMessage = "Unable to process Apple Sign In credentials."
                return
            }

            isLoading = true
            errorMessage = nil

            do {
                _ = try await authService.signInWithApple(idToken: idToken, nonce: nonce)

                if let fullName = extractFullName(from: credential) {
                    try? await authService.updateUserFullName(fullName)
                }
            } catch {
                errorMessage = mapError(error)
            }

            isLoading = false
            currentNonce = nil

        case let .failure(error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            errorMessage = mapError(error)
        }
    }

    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256Hash(nonce)
    }

    func signInWithGoogle() async {
        guard let redirectURL = URL(string: "cadence://auth-callback") else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await authService.signInWithGoogle(redirectTo: redirectURL)
        } catch {
            let nsError = error as NSError
            let webAuthDomain = "com.apple.AuthenticationServices.WebAuthenticationSession"
            let isWebAuthCancellation = nsError.domain == webAuthDomain && nsError.code == 1
            if isWebAuthCancellation {
                isLoading = false
                return
            }
            errorMessage = mapError(error)
        }

        isLoading = false
    }

    private func extractFullName(from credential: ASAuthorizationAppleIDCredential) -> String? {
        guard let nameComponents = credential.fullName else { return nil }
        let given = nameComponents.givenName
        let family = nameComponents.familyName
        guard given != nil || family != nil else { return nil }
        return [given, family].compactMap { $0 }.joined(separator: " ")
    }

    private func mapError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()
        let isInvalidCredentials = description.contains("invalid login credentials")
            || description.contains("invalid_credentials")
        if isInvalidCredentials {
            return "Incorrect email or password."
        }
        let isAlreadyRegistered = description.contains("already registered")
            || description.contains("user_already_exists")
        if isAlreadyRegistered {
            return "An account with this email already exists. Sign in instead."
        }
        if error is URLError {
            return "Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            for byte in randomBytes where remainingLength > 0 {
                let index = Int(byte) % charset.count
                result.append(charset[index])
                remainingLength -= 1
            }
        }
        return result
    }

    private func sha256Hash(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
