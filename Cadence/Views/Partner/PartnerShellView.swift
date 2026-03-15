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
            }
        }
    }
}
