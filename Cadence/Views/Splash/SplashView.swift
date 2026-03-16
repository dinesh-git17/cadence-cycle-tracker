import SwiftUI

struct SplashView: View {
    var onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drawProgress: CGFloat = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var animationTask: Task<Void, Never>?

    private let markWidth: CGFloat = 160
    private let markHeight: CGFloat = 120
    private let strokeWidth: CGFloat = 28
    private let markWordmarkSpacing: CGFloat = 24
    private let animatedHoldDelay: Double = 2.05
    private let reducedMotionHoldDelay: Double = 0.4

    var body: some View {
        ZStack {
            Color("CadenceBackground")
                .ignoresSafeArea()

            VStack(spacing: markWordmarkSpacing) {
                CadenceMark()
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        Color("CadenceMark"),
                        style: StrokeStyle(
                            lineWidth: strokeWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: markWidth, height: markHeight)

                Text("Cadence")
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.light)
                    .foregroundStyle(.primary)
                    .opacity(wordmarkOpacity)
            }
        }
        .onAppear {
            guard drawProgress == 0 else { return }
            runEntrance()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func runEntrance() {
        if reduceMotion {
            drawProgress = 1.0
            wordmarkOpacity = 1.0
            animationTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(reducedMotionHoldDelay))
                guard !Task.isCancelled else { return }
                onComplete()
            }
        } else {
            withAnimation(.easeInOut(duration: 1.0).delay(0.2)) {
                drawProgress = 1.0
            }
            withAnimation(.easeOut(duration: 0.35).delay(1.3)) {
                wordmarkOpacity = 1.0
            }
            animationTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(animatedHoldDelay))
                guard !Task.isCancelled else { return }
                onComplete()
            }
        }
    }
}
