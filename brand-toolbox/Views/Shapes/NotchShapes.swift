import SwiftUI

// MARK: - Closed Pill Shape (Dynamic Island compact pill)

public struct ClosedPillShape: Shape {
    public var cornerRadius: CGFloat?

    public init(cornerRadius: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius ?? rect.height / 2, rect.width / 2, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("Closed Pill Shape") {
    VStack(spacing: 20) {
        ClosedPillShape()
            .fill(Color.black)
            .frame(width: 180, height: 32)
            .overlay(
                Text("Dynamic Island")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
            )

        ClosedPillShape(cornerRadius: 12)
            .fill(Color.accentColor)
            .frame(width: 220, height: 44)
            .overlay(
                Text("Custom Radius")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    .padding(30)
    .background(Color.gray.opacity(0.15))
}
