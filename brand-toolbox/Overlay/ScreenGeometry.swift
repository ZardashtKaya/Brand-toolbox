import AppKit

extension NSScreen {
    public var hasNotch: Bool {
        return auxiliaryTopLeftArea != nil
    }

    public var notchHeight: CGFloat {
        if let topLeft = auxiliaryTopLeftArea {
            return topLeft.height
        }
        return 36
    }

    public var notchWidth: CGFloat {
        if let topLeft = auxiliaryTopLeftArea, let topRight = auxiliaryTopRightArea {
            let width = topRight.minX - topLeft.maxX
            if width > 0 {
                return width
            }
        }
        return 210
    }
}
