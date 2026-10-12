import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Overlay Mode

public enum OverlayPositionMode: String, Codable, CaseIterable, Identifiable {
    case leftDock = "left_dock"
    case dynamicIsland = "dynamic_island"
    case rightDock = "right_dock"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .leftDock: return "Left Dock"
        case .dynamicIsland: return "Dynamic Island / Notch"
        case .rightDock: return "Right Dock"
        }
    }

    public var iconName: String {
        switch self {
        case .leftDock: return "sidebar.left"
        case .dynamicIsland: return "capsule.portrait"
        case .rightDock: return "sidebar.right"
        }
    }
}

// MARK: - Copy Format

public enum CopyFormat: String, Codable, CaseIterable, Identifiable {
    case hexHash = "hex_hash"
    case hexPlain = "hex_plain"
    case rgb = "rgb"
    case swiftUI = "swiftui"
    case cssVar = "css_var"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hexHash: return "#HEX (#0071E3)"
        case .hexPlain: return "HEX (0071E3)"
        case .rgb: return "rgb(0, 113, 227)"
        case .swiftUI: return "Color(hex: \"#0071E3\")"
        case .cssVar: return "--color: #0071E3"
        }
    }
}

// MARK: - Color Role

public enum ColorRole: String, Codable, CaseIterable, Identifiable {
    case primary = "Primary"
    case secondary = "Secondary"
    case accent = "Accent"
    case background = "Background"
    case surface = "Surface"
    case custom = "Custom"

    public var id: String { rawValue }
}

// MARK: - Brand Color

public struct BrandColor: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var hex: String
    public var role: ColorRole

    public init(id: UUID = UUID(), name: String, hex: String, role: ColorRole = .primary) {
        self.id = id
        self.name = name
        self.hex = hex.uppercased()
        self.role = role
    }

    public var normalizedHex: String {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }
        return clean
    }

    public var formattedHex: String {
        "#" + normalizedHex
    }

    public var swiftUIColor: Color {
        Color(hex: formattedHex)
    }

    public var nsColor: NSColor {
        NSColor(hex: formattedHex) ?? .black
    }

    public var isDark: Bool {
        let (r, g, b) = rgbComponents
        // Relative luminance approximation
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.55
    }

    public var contrastTextColor: Color {
        isDark ? .white : .black
    }

    public var rgbComponents: (r: Double, g: Double, b: Double) {
        let clean = normalizedHex
        var rgbValue: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgbValue)

        let r: Double
        let g: Double
        let b: Double

        if clean.count == 6 {
            r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            b = Double(rgbValue & 0x0000FF) / 255.0
        } else if clean.count == 3 {
            r = Double(((rgbValue & 0xF00) >> 8) * 17) / 255.0
            g = Double(((rgbValue & 0x0F0) >> 4) * 17) / 255.0
            b = Double((rgbValue & 0x00F) * 17) / 255.0
        } else {
            r = 0; g = 0; b = 0
        }
        return (r, g, b)
    }

    public func formatted(for format: CopyFormat) -> String {
        let clean = normalizedHex
        let (r, g, b) = rgbComponents
        let rInt = Int(round(r * 255))
        let gInt = Int(round(g * 255))
        let bInt = Int(round(b * 255))

        switch format {
        case .hexHash:
            return "#" + clean
        case .hexPlain:
            return clean
        case .rgb:
            return "rgb(\(rInt), \(gInt), \(bInt))"
        case .swiftUI:
            return "Color(hex: \"#\(clean)\")"
        case .cssVar:
            let sanitizedName = name.lowercased().replacingOccurrences(of: " ", with: "-")
            return "--brand-\(sanitizedName): #\(clean);"
        }
    }
}

// MARK: - Logo Type

public enum LogoType: String, Codable, CaseIterable {
    case file = "file"
    case systemSymbol = "symbol"
    case generated = "generated"
}

// MARK: - Brand Logo

public struct BrandLogo: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var type: LogoType
    public var fileName: String?
    public var systemSymbol: String?
    public var isDarkVariant: Bool
    public var accentColorHex: String?

    public init(
        id: UUID = UUID(),
        name: String,
        type: LogoType = .file,
        fileName: String? = nil,
        systemSymbol: String? = nil,
        isDarkVariant: Bool = false,
        accentColorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.fileName = fileName
        self.systemSymbol = systemSymbol
        self.isDarkVariant = isDarkVariant
        self.accentColorHex = accentColorHex
    }
}

// MARK: - Brand Font

public struct BrandFont: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var role: String

    public init(id: UUID = UUID(), name: String, role: String = "Primary") {
        self.id = id
        self.name = name
        self.role = role
    }
}

// MARK: - Brand Model

public struct Brand: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var tagline: String
    public var iconSymbol: String
    public var accentColorHex: String
    public var colors: [BrandColor]
    public var logos: [BrandLogo]
    public var fonts: [BrandFont]
    public var isFavorite: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        tagline: String = "",
        iconSymbol: String = "paintpalette.fill",
        accentColorHex: String = "#0071E3",
        colors: [BrandColor] = [],
        logos: [BrandLogo] = [],
        fonts: [BrandFont] = [],
        isFavorite: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.iconSymbol = iconSymbol
        self.accentColorHex = accentColorHex
        self.colors = colors
        self.logos = logos
        self.fonts = fonts
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, tagline, iconSymbol, accentColorHex, colors, logos, fonts, isFavorite, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tagline = try container.decodeIfPresent(String.self, forKey: .tagline) ?? ""
        iconSymbol = try container.decodeIfPresent(String.self, forKey: .iconSymbol) ?? "paintpalette.fill"
        accentColorHex = try container.decodeIfPresent(String.self, forKey: .accentColorHex) ?? "#0071E3"
        colors = try container.decodeIfPresent([BrandColor].self, forKey: .colors) ?? []
        logos = try container.decodeIfPresent([BrandLogo].self, forKey: .logos) ?? []
        fonts = try container.decodeIfPresent([BrandFont].self, forKey: .fonts) ?? []
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    public var accentColor: Color {
        Color(hex: accentColorHex)
    }

    public var primaryColor: BrandColor? {
        colors.first(where: { $0.role == .primary }) ?? colors.first
    }
}

// MARK: - Color Hex Extensions

extension Color {
    public init(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }

        var rgbValue: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgbValue)

        let r, g, b, a: Double
        if clean.count == 6 {
            r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
            g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
            b = Double(rgbValue & 0x0000FF) / 255.0
            a = 1.0
        } else if clean.count == 8 {
            r = Double((rgbValue & 0xFF000000) >> 24) / 255.0
            g = Double((rgbValue & 0x00FF0000) >> 16) / 255.0
            b = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
            a = Double(rgbValue & 0x000000FF) / 255.0
        } else if clean.count == 3 {
            r = Double(((rgbValue & 0xF00) >> 8) * 17) / 255.0
            g = Double(((rgbValue & 0x0F0) >> 4) * 17) / 255.0
            b = Double((rgbValue & 0x00F) * 17) / 255.0
            a = 1.0
        } else {
            r = 0.5; g = 0.5; b = 0.5; a = 1.0
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    public func toHex(includeHash: Bool = true) -> String {
        let nsColor = NSColor(self)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else {
            return includeHash ? "#000000" : "000000"
        }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        let hex = String(format: "%02X%02X%02X", r, g, b)
        return includeHash ? "#" + hex : hex
    }
}

extension NSColor {
    public convenience init?(hex: String) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }

        var rgbValue: UInt64 = 0
        guard Scanner(string: clean).scanHexInt64(&rgbValue) else { return nil }

        let r, g, b: CGFloat
        if clean.count == 6 {
            r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgbValue & 0x0000FF) / 255.0
        } else if clean.count == 3 {
            r = CGFloat(((rgbValue & 0xF00) >> 8) * 17) / 255.0
            g = CGFloat(((rgbValue & 0x0F0) >> 4) * 17) / 255.0
            b = CGFloat((rgbValue & 0x00F) * 17) / 255.0
        } else {
            return nil
        }

        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
