import SwiftUI

struct CadenceMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // Sweeping "C" brushstroke matching the app icon.
        // Starts at upper-right tip, arcs counterclockwise
        // through the left side, ends at lower-right tail.
        path.move(to: CGPoint(
            x: width * 0.78,
            y: height * 0.08
        ))
        path.addCurve(
            to: CGPoint(x: width * 0.13, y: height * 0.50),
            control1: CGPoint(x: width * 0.38, y: height * 0.0),
            control2: CGPoint(x: width * 0.06, y: height * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.88, y: height * 0.72),
            control1: CGPoint(x: width * 0.20, y: height * 0.82),
            control2: CGPoint(x: width * 0.66, y: height * 0.84)
        )
        return path
    }
}
