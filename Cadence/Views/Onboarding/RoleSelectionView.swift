import SwiftUI

struct RoleSelectionView: View {
    var onRoleSelected: (UserRole) -> Void

    @State private var isLoading = false
    @State private var selectedRole: UserRole?
    @State private var errorMessage: String?

    private let ctaHeight: CGFloat = 50
    private let ctaCornerRadius: CGFloat = 14
    private let screenMargin: CGFloat = 16
    private let sectionSpacing: CGFloat = 24

    var body: some View {
        ZStack {
            Color("CadenceBackground")
                .ignoresSafeArea()

            VStack(spacing: sectionSpacing) {
                Spacer()

                Text("How will you use Cadence?")
                    .font(.title2)
                    .foregroundStyle(Color("CadenceTextPrimary"))
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    roleButton(
                        title: "I track my cycle",
                        role: .tracker
                    )
                    roleButton(
                        title: "My partner tracks their cycle",
                        role: .partner
                    )
                }

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
        }
    }

    private func roleButton(title: String, role: UserRole) -> some View {
        Button {
            Task { await selectRole(role) }
        } label: {
            ZStack {
                if isLoading && selectedRole == role {
                    ProgressView()
                        .tint(Color("CadenceTextOnAccent"))
                } else {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            selectedRole == role
                                ? Color("CadenceTextOnAccent")
                                : Color("CadenceTextPrimary")
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: ctaHeight)
            .background(
                selectedRole == role
                    ? Color("CadenceTerracotta")
                    : Color("CadenceCard")
            )
            .clipShape(RoundedRectangle(cornerRadius: ctaCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ctaCornerRadius)
                    .stroke(
                        selectedRole == role
                            ? Color.clear
                            : Color("CadenceBorder"),
                        lineWidth: 1
                    )
            )
        }
        .disabled(isLoading)
        .frame(minHeight: 44)
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
