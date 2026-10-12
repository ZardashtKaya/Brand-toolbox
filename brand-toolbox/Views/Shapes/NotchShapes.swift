import SwiftUI

// MARK: - Notch Shape (Concave top for MacBook notch integration)

public struct NotchShape: Shape {
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    public init(topCornerRadius: CGFloat = 20, bottomCornerRadius: CGFloat = 22) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let topR = min(topCornerRadius, rect.width / 4, rect.height / 4)
        let botR = min(bottomCornerRadius, rect.width / 4, rect.height / 2)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left concave curve
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR, y: rect.minY + topR),
            control: CGPoint(x: rect.minX + topR, y: rect.minY)
        )

        // Left edge
        path.addLine(to: CGPoint(x: rect.minX + topR, y: rect.maxY - botR))

        // Bottom-left rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR + botR, y: rect.maxY),
            control: CGPoint(x: rect.minX + topR, y: rect.maxY)
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.maxX - topR - botR, y: rect.maxY))

        // Bottom-right rounded corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topR, y: rect.maxY - botR),
            control: CGPoint(x: rect.maxX - topR, y: rect.maxY)
        )

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY + topR))

        // Top-right concave curve
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topR, y: rect.minY)
        )

        // Top edge back
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Closed Pill Shape (Dynamic island compact pill)

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

// MARK: - Left Edge Dock Shape

public struct LeftDockShape: Shape {
    public var cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 24) {
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.width / 2, rect.height / 2)
        var path = Path()

        // Start top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top edge towards top-right
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))

        // Top-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )

        // Right edge downwards
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))

        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom edge back to left
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))

        // Left edge straight against screen bezel
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        path.closeSubpath()
        return path
    }
}
