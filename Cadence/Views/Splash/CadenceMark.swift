import SwiftUI

struct CadenceMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(
            x: width * 0.18,
            y: height * 0.72
        ))
        path.addCurve(
            to: CGPoint(x: width * 0.80, y: height * 0.26),
            control1: CGPoint(x: width * 0.20, y: height * 0.16),
            control2: CGPoint(x: width * 0.62, y: height * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.64, y: height * 0.70),
            control1: CGPoint(x: width * 0.96, y: height * 0.40),
            control2: CGPoint(x: width * 0.88, y: height * 0.66)
        )
        return path
    }
}
