import SwiftUI

public struct CheckerboardView: View {
    public var squareSize: CGFloat = 8

    public init(squareSize: CGFloat = 8) {
        self.squareSize = squareSize
    }

    public var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))

            for row in 0..<rows {
                for col in 0..<cols {
                    let isEven = (row + col) % 2 == 0
                    let color = isEven ? Color.white.opacity(0.12) : Color.white.opacity(0.04)
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
    }
}
