import SwiftUI

@main
struct CadenceApp: App {
    @State private var authState = AuthState()
    @State private var coordinator: AppCoordinator

    init() {
        let state = AuthState()
        _authState = State(initialValue: state)
        _coordinator = State(initialValue: AppCoordinator(authState: state))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(coordinator)
                .task {
                    await coordinator.resolveInitialRoute()
                    observeAuthChanges()
                }
                .onOpenURL { url in
                    supabase.handle(url)
                }
        }
    }

    private func observeAuthChanges() {
        Task { @MainActor in
            for await (event, _) in supabase.auth.authStateChanges {
                switch event {
                case .signedIn:
                    if coordinator.currentRoute == .auth {
                        await coordinator.handleSignedIn()
                    }
                case .signedOut:
                    coordinator.handleSignedOut()
                default:
                    break
                }
            }
        }
    }
}
