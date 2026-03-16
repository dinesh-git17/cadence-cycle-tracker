import SwiftUI

struct PartnerShellView: View {
    var body: some View {
        ZStack {
            Color("CadenceBackground")
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "person.crop.rectangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color("CadenceTerracotta"))

                Text("Partner")
                    .font(.title2)
                    .foregroundStyle(Color("CadenceTextPrimary"))

                Text("Full shell arriving in Phase 9")
                    .font(.subheadline)
                    .foregroundStyle(Color("CadenceTextSecondary"))

                signOutButton
            }
        }
    }

    private var signOutButton: some View {
        Button {
            Task {
                try? await supabase.auth.signOut()
            }
        } label: {
            Text("Sign out")
                .font(.footnote)
                .foregroundStyle(Color("CadenceTerracotta"))
        }
        .frame(minHeight: 44)
        .padding(.top, 24)
    }
}
