import SwiftUI

struct GoogleLogo: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let lineWidth = radius * 0.38

            let blueArc = Path { path in
                path.addArc(
                    center: center, radius: radius - lineWidth / 2,
                    startAngle: .degrees(-45), endAngle: .degrees(45),
                    clockwise: false
                )
            }
            context.stroke(blueArc, with: .color(Color("GoogleBlue")), lineWidth: lineWidth)

            let greenArc = Path { path in
                path.addArc(
                    center: center, radius: radius - lineWidth / 2,
                    startAngle: .degrees(45), endAngle: .degrees(150),
                    clockwise: false
                )
            }
            context.stroke(greenArc, with: .color(Color("GoogleGreen")), lineWidth: lineWidth)

            let yellowArc = Path { path in
                path.addArc(
                    center: center, radius: radius - lineWidth / 2,
                    startAngle: .degrees(150), endAngle: .degrees(225),
                    clockwise: false
                )
            }
            context.stroke(yellowArc, with: .color(Color("GoogleYellow")), lineWidth: lineWidth)

            let redArc = Path { path in
                path.addArc(
                    center: center, radius: radius - lineWidth / 2,
                    startAngle: .degrees(225), endAngle: .degrees(315),
                    clockwise: false
                )
            }
            context.stroke(redArc, with: .color(Color("GoogleRed")), lineWidth: lineWidth)

            let barWidth = radius * 0.9
            let barHeight = lineWidth
            let barRect = CGRect(
                x: center.x,
                y: center.y - barHeight / 2,
                width: barWidth,
                height: barHeight
            )
            context.fill(Path(barRect), with: .color(Color("GoogleBlue")))
        }
    }
}
