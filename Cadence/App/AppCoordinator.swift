import Foundation
import Observation
import Supabase

enum AppRoute: Equatable, Sendable {
    case loading
    case splash
    case auth
    case roleSelection
    case trackerOnboarding
    case partnerOnboarding
    case trackerShell
    case partnerShell
}

@Observable
@MainActor
final class AppCoordinator {
    var currentRoute: AppRoute = .loading

    private let authState: AuthState

    init(authState: AuthState) {
        self.authState = authState
    }

    func resolveInitialRoute() async {
        do {
            let session = try await supabase.auth.session
            let userRole = try? await fetchUserRole(userId: session.user.id)

            if let role = userRole {
                currentRoute = role == .tracker ? .trackerShell : .partnerShell
            } else {
                currentRoute = .roleSelection
            }
        } catch {
            currentRoute = .splash
        }
    }

    func handleSplashComplete() {
        currentRoute = .auth
    }

    func handleSignedIn() async {
        guard let session = authState.currentSession else {
            currentRoute = .auth
            return
        }
        let userRole = try? await fetchUserRole(userId: session.user.id)
        if let role = userRole {
            currentRoute = role == .tracker ? .trackerShell : .partnerShell
        } else {
            currentRoute = .roleSelection
        }
    }

    func handleSignedOut() {
        currentRoute = .auth
    }

    func handleRoleSelected(_ role: UserRole) {
        switch role {
        case .tracker:
            currentRoute = .trackerOnboarding
        case .partner:
            currentRoute = .partnerOnboarding
        }
    }

    func handleOnboardingComplete(role: UserRole) {
        switch role {
        case .tracker:
            currentRoute = .trackerShell
        case .partner:
            currentRoute = .partnerShell
        }
    }

    private func fetchUserRole(userId: UUID) async throws -> UserRole? {
        struct UserRow: Decodable {
            let role: String?
        }

        let rows: [UserRow] = try await supabase
            .from("users")
            .select("role")
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let roleString = rows.first?.role else { return nil }
        return UserRole(rawValue: roleString)
    }
}
