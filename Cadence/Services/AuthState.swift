import Auth
import Foundation
import Observation

@Observable
@MainActor
final class AuthState {
    var currentSession: Session?
    var isSignedIn: Bool {
        currentSession != nil
    }

    private var listenerTask: Task<Void, Never>?

    init() {
        startListening()
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            listenerTask?.cancel()
        }
    }

    private func startListening() {
        listenerTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                guard !Task.isCancelled else { return }
                switch event {
                case .signedIn, .tokenRefreshed, .initialSession:
                    self.currentSession = session
                case .signedOut:
                    self.currentSession = nil
                default:
                    break
                }
            }
        }
    }
}
