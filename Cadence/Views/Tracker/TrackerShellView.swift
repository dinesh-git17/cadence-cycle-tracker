import SwiftUI

struct TrackerShellView: View {
    var body: some View {
        ZStack {
            Color("CadenceBackground")
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "house.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color("CadenceTerracotta"))

                Text("Tracker")
                    .font(.title2)
                    .foregroundStyle(Color("CadenceTextPrimary"))

                Text("Full shell arriving in Phase 4")
                    .font(.subheadline)
                    .foregroundStyle(Color("CadenceTextSecondary"))
            }
        }
    }
}
