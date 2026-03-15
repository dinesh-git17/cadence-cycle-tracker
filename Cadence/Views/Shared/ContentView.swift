import SwiftUI

struct ContentView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch coordinator.currentRoute {
            case .loading:
                Color("CadenceBackground")
                    .ignoresSafeArea()

            case .splash:
                SplashView {
                    setRoute(.auth)
                }
                .transition(.opacity)

            case .auth:
                AuthView()
                    .transition(.opacity)

            case .roleSelection:
                RoleSelectionView { role in
                    setRoute(
                        role == .tracker ? .trackerOnboarding : .partnerOnboarding
                    )
                }
                .transition(.opacity)

            case .trackerOnboarding:
                TrackerOnboardingView {
                    setRoute(.trackerShell)
                }
                .transition(.opacity)

            case .partnerOnboarding:
                PartnerOnboardingView {
                    setRoute(.partnerShell)
                }
                .transition(.opacity)

            case .trackerShell:
                TrackerShellView()
                    .transition(.opacity)

            case .partnerShell:
                PartnerShellView()
                    .transition(.opacity)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.3),
            value: coordinator.currentRoute
        )
    }

    private func setRoute(_ route: AppRoute) {
        coordinator.currentRoute = route
    }
}
