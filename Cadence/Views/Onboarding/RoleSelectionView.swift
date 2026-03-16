import SwiftUI

private struct RoleCardConfig {
    let icon: String
    let iconColor: Color
    let iconBackground: Color
    let title: String
    let description: String
    let role: UserRole
}

struct RoleSelectionView: View {
    var onRoleSelected: (UserRole) -> Void

    @State private var isLoading = false
    @State private var selectedRole: UserRole?
    @State private var errorMessage: String?

    private let cardCornerRadius: CGFloat = 16
    private let iconBackgroundSize: CGFloat = 56
    private let iconCornerRadius: CGFloat = 14
    private let screenMargin: CGFloat = 16
    private let cardPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 16

    var body: some View {
        ZStack {
            Color("CadenceBackground")
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: sectionSpacing) {
                Text("How will you\nuse Cadence?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("CadenceTextPrimary"))

                Text("This can't be changed later.")
                    .font(.subheadline)
                    .foregroundStyle(Color("CadenceTextSecondary"))

                Spacer()
                    .frame(height: 8)

                roleCard(.init(
                    icon: "circle.fill",
                    iconColor: Color("CadenceTerracotta"),
                    iconBackground: Color("CadenceTerracotta").opacity(0.15),
                    title: "I track my cycle",
                    description: "Log your period, symptoms, and cycle data. Control what you share with a partner.",
                    role: .tracker
                ))

                roleCard(.init(
                    icon: "heart.fill",
                    iconColor: Color("CadenceSage"),
                    iconBackground: Color("CadenceSageLight"),
                    title: "My partner tracks their cycle",
                    description: "See what your partner shares with you. Read-only access to their cycle data.",
                    role: .partner
                ))

                if let errorMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(errorMessage)
                    }
                    .font(.footnote)
                    .foregroundStyle(Color("CadenceTextSecondary"))
                }

                Spacer()
            }
            .padding(.horizontal, screenMargin)
            .padding(.top, 60)
        }
    }

    private func roleCard(_ config: RoleCardConfig) -> some View {
        Button {
            Task { await selectRole(config.role) }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    if isLoading && selectedRole == config.role {
                        ProgressView()
                            .tint(Color("CadenceTextPrimary"))
                    } else {
                        RoundedRectangle(cornerRadius: iconCornerRadius)
                            .fill(config.iconBackground)
                            .frame(width: iconBackgroundSize, height: iconBackgroundSize)
                            .overlay(
                                Image(systemName: config.icon)
                                    .font(.title3)
                                    .foregroundStyle(config.iconColor)
                            )
                    }
                }

                Text(config.title)
                    .font(.headline)
                    .foregroundStyle(Color("CadenceTextPrimary"))

                Text(config.description)
                    .font(.subheadline)
                    .foregroundStyle(Color("CadenceTextSecondary"))
                    .multilineTextAlignment(.center)
            }
            .padding(cardPadding)
            .frame(maxWidth: .infinity)
            .background(Color("CadenceCard"))
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .stroke(Color("CadenceBorder"), lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }

    private func selectRole(_ role: UserRole) async {
        selectedRole = role
        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.session

            struct UserUpsert: Encodable {
                let id: UUID
                let role: String
                let timezone: String
            }

            let upsertData = UserUpsert(
                id: session.user.id,
                role: role.rawValue,
                timezone: TimeZone.current.identifier
            )

            try await supabase
                .from("users")
                .upsert(upsertData, onConflict: "id")
                .execute()

            onRoleSelected(role)
        } catch {
            errorMessage = "Something went wrong. Please try again."
        }

        isLoading = false
    }
}
