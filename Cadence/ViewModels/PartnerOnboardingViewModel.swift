import Foundation
import Observation

enum CodeValidationResult: Equatable, Sendable {
    case valid(connectionId: UUID)
    case notFound
    case expired
    case alreadyUsed
    case networkError
}

@Observable
@MainActor
final class PartnerOnboardingViewModel {
    var inviteCode = ""
    var isLoading = false
    var validationResult: CodeValidationResult?
    var validatedConnectionId: UUID?

    var isCodeComplete: Bool {
        inviteCode.count == requiredCodeLength
    }

    var shouldShowError: Bool {
        guard let result = validationResult else { return false }
        switch result {
        case .valid: return false
        default: return true
        }
    }

    var errorMessage: String? {
        guard let result = validationResult else { return nil }
        switch result {
        case .valid:
            return nil
        case .notFound:
            return ErrorMessages.codeNotFound
        case .expired:
            return ErrorMessages.codeExpired
        case .alreadyUsed:
            return ErrorMessages.codeAlreadyUsed
        case .networkError:
            return ErrorMessages.networkError
        }
    }

    private let requiredCodeLength = 6
    private let expiryInterval: TimeInterval = 86400

    func sanitizeInput(_ newValue: String) {
        let filtered = String(newValue.filter(\.isNumber).prefix(requiredCodeLength))
        if inviteCode != filtered {
            inviteCode = filtered
        }
    }

    func clearError() {
        validationResult = nil
    }

    func validateCode(
        onSuccess: @escaping () -> Void,
        performQuery: ((String) async throws -> [PartnerConnection])? = nil
    ) async {
        guard isCodeComplete else { return }
        isLoading = true
        validationResult = nil

        do {
            let rows: [PartnerConnection]
            if let performQuery {
                rows = try await performQuery(inviteCode)
            } else {
                rows = try await supabase
                    .from("partner_connections")
                    .select("id, invite_code, created_at, partner_id")
                    .eq("invite_code", value: inviteCode)
                    .limit(1)
                    .execute()
                    .value
            }

            guard let connection = rows.first else {
                validationResult = .notFound
                inviteCode = ""
                isLoading = false
                return
            }

            if connection.partnerId != nil {
                validationResult = .alreadyUsed
                isLoading = false
                return
            }

            if Date.now.timeIntervalSince(connection.createdAt) > expiryInterval {
                validationResult = .expired
                isLoading = false
                return
            }

            validatedConnectionId = connection.connectionId
            validationResult = .valid(connectionId: connection.connectionId)
            onSuccess()
        } catch {
            validationResult = .networkError
        }

        isLoading = false
    }
}

private enum ErrorMessages {
    static let codeNotFound = "Code not found. Check the code and try again."
    static let codeExpired = "This code has expired. Ask your partner for a new one."
    static let codeAlreadyUsed = "This code has already been used."
    static let networkError = "Could not connect. Check your network and try again."
}
