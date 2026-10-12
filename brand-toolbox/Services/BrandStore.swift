import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

@MainActor
public final class BrandStore: ObservableObject {
    public static let shared = BrandStore()

    @Published public var brands: [Brand] = []
    @Published public var selectedBrandId: UUID?
    @Published public var searchQuery: String = ""
    @Published public var overlayMode: OverlayPositionMode = .leftDock
    @Published public var isPinned: Bool = false
    @Published public var copyFormat: CopyFormat = .hexHash
    @Published public var soundAndHaptics: Bool = true
    @Published public var edgeSensitivityPx: Double = 10.0
    @Published public var autoHideDelay: Double = 0.35
    @Published public var lastCopiedHex: String? = nil
    @Published public var copiedToastMessage: String? = nil

    private var toastTimer: Task<Void, Never>?

    private let fileManager = FileManager.default
    private var appSupportURL: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("BrandToolbox", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public var assetsDirectoryURL: URL {
        let dir = appSupportURL.appendingPathComponent("assets", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var brandsFileURL: URL {
        appSupportURL.appendingPathComponent("brands.json")
    }

    private var preferencesFileURL: URL {
        appSupportURL.appendingPathComponent("preferences.json")
    }

    public var selectedBrand: Brand? {
        if let id = selectedBrandId, let found = brands.first(where: { $0.id == id }) {
            return found
        }
        return brands.first
    }

    public var filteredColors: [BrandColor] {
        guard let brand = selectedBrand else { return [] }
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return brand.colors
        }
        let q = searchQuery.lowercased()
        return brand.colors.filter {
            $0.name.lowercased().contains(q) || $0.hex.lowercased().contains(q)
        }
    }

    public var filteredLogos: [BrandLogo] {
        guard let brand = selectedBrand else { return [] }
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return brand.logos
        }
        let q = searchQuery.lowercased()
        return brand.logos.filter {
            $0.name.lowercased().contains(q)
        }
    }

    public init() {
        loadPreferences()
        loadBrands()
    }

    // MARK: - Persistence

    public func saveBrands() {
        do {
            let data = try JSONEncoder().encode(brands)
            try data.write(to: brandsFileURL, options: .atomic)
        } catch {
            print("Failed to save brands: \(error)")
        }
    }

    public func loadBrands() {
        if fileManager.fileExists(atPath: brandsFileURL.path) {
            do {
                let data = try Data(contentsOf: brandsFileURL)
                let loaded = try JSONDecoder().decode([Brand].self, from: data)
                if !loaded.isEmpty {
                    self.brands = loaded
                    if selectedBrandId == nil || !loaded.contains(where: { $0.id == selectedBrandId }) {
                        self.selectedBrandId = loaded.first?.id
                    }
                    generateMissingPresetImages()
                    return
                }
            } catch {
                print("Failed to load brands: \(error)")
            }
        }

        // Initialize with realistic presets
        self.brands = defaultPresetBrands()
        self.selectedBrandId = self.brands.first?.id
        saveBrands()
        generateMissingPresetImages()
    }

    public func savePreferences() {
        struct Prefs: Codable {
            var mode: OverlayPositionMode
            var pinned: Bool
            var format: CopyFormat
            var sound: Bool
            var sensitivity: Double
            var hideDelay: Double
            var selectedBrand: UUID?
        }
        let prefs = Prefs(
            mode: overlayMode,
            pinned: isPinned,
            format: copyFormat,
            sound: soundAndHaptics,
            sensitivity: edgeSensitivityPx,
            hideDelay: autoHideDelay,
            selectedBrand: selectedBrandId
        )
        if let data = try? JSONEncoder().encode(prefs) {
            try? data.write(to: preferencesFileURL, options: .atomic)
        }
    }

    public func loadPreferences() {
        struct Prefs: Codable {
            var mode: OverlayPositionMode
            var pinned: Bool
            var format: CopyFormat
            var sound: Bool
            var sensitivity: Double
            var hideDelay: Double
            var selectedBrand: UUID?
        }
        guard let data = try? Data(contentsOf: preferencesFileURL),
              let prefs = try? JSONDecoder().decode(Prefs.self, from: data) else {
            return
        }
        self.overlayMode = prefs.mode
        self.isPinned = prefs.pinned
        self.copyFormat = prefs.format
        self.soundAndHaptics = prefs.sound
        self.edgeSensitivityPx = prefs.sensitivity
        self.autoHideDelay = prefs.hideDelay
        self.selectedBrandId = prefs.selectedBrand
    }

    // MARK: - Clipboard & Feedback

    public func copyColor(_ color: BrandColor, format: CopyFormat? = nil) {
        let fmt = format ?? self.copyFormat
        let textToCopy = color.formatted(for: fmt)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToCopy, forType: .string)

        self.lastCopiedHex = color.formattedHex
        showToast(message: "Copied \(textToCopy)")

        if soundAndHaptics {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .now
            )
            NSSound(named: "Tink")?.play()
        }
    }

    public func copyLogoImage(_ logo: BrandLogo) {
        guard let image = imageForLogo(logo) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])

        showToast(message: "Copied '\(logo.name)' to clipboard")

        if soundAndHaptics {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .now
            )
            NSSound(named: "Pop")?.play()
        }
    }

    public func showToast(message: String) {
        toastTimer?.cancel()
        copiedToastMessage = message
        toastTimer = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if !Task.isCancelled {
                self.copiedToastMessage = nil
                self.lastCopiedHex = nil
            }
        }
    }

    // MARK: - Logo File & Image Handling

    public func fileURLForLogo(_ logo: BrandLogo) -> URL? {
        if let fileName = logo.fileName {
            let url = assetsDirectoryURL.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: url.path) {
                return url
            }
        }
        // If file doesn't exist, create it if it has a system symbol
        if let symbol = logo.systemSymbol {
            let fileName = "\(logo.id.uuidString).png"
            let targetURL = assetsDirectoryURL.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: targetURL.path) {
                if let image = renderSymbolToImage(symbol: symbol, accentHex: logo.accentColorHex) {
                    if let tiff = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: targetURL)
                        return targetURL
                    }
                }
            } else {
                return targetURL
            }
        }
        return nil
    }

    public func imageForLogo(_ logo: BrandLogo) -> NSImage? {
        if let fileName = logo.fileName {
            let fileURL = assetsDirectoryURL.appendingPathComponent(fileName)
            if let img = NSImage(contentsOf: fileURL) {
                return img
            }
        }
        if let symbol = logo.systemSymbol {
            return renderSymbolToImage(symbol: symbol, accentHex: logo.accentColorHex)
        }
        return NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
    }

    private func renderSymbolToImage(symbol: String, accentHex: String?) -> NSImage? {
        let size = NSSize(width: 128, height: 128)
        let image = NSImage(size: size)
        image.lockFocus()

        let context = NSGraphicsContext.current?.cgContext
        context?.clear(CGRect(origin: .zero, size: size))

        let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .semibold)
        let tintColor: NSColor
        if let hex = accentHex, let custom = NSColor(hex: hex) {
            tintColor = custom
        } else {
            tintColor = .white
        }

        if let baseImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let rect = NSRect(
                x: (size.width - baseImage.size.width) / 2,
                y: (size.height - baseImage.size.height) / 2,
                width: baseImage.size.width,
                height: baseImage.size.height
            )

            tintColor.set()
            baseImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        image.unlockFocus()
        return image
    }

    private func generateMissingPresetImages() {
        for (bIndex, brand) in brands.enumerated() {
            for (lIndex, logo) in brand.logos.enumerated() {
                if logo.fileName == nil && logo.systemSymbol != nil {
                    let fileName = "\(logo.id.uuidString).png"
                    let targetURL = assetsDirectoryURL.appendingPathComponent(fileName)
                    if let img = renderSymbolToImage(symbol: logo.systemSymbol!, accentHex: logo.accentColorHex) {
                        if let tiff = img.tiffRepresentation,
                           let bitmap = NSBitmapImageRep(data: tiff),
                           let pngData = bitmap.representation(using: .png, properties: [:]) {
                            try? pngData.write(to: targetURL)
                            brands[bIndex].logos[lIndex].fileName = fileName
                        }
                    }
                }
            }
        }
    }

    // MARK: - Brand CRUD

    public func addBrand(name: String, tagline: String, iconSymbol: String, accentHex: String) {
        let newBrand = Brand(
            name: name,
            tagline: tagline,
            iconSymbol: iconSymbol,
            accentColorHex: accentHex,
            colors: [
                BrandColor(name: "Primary", hex: accentHex, role: .primary),
                BrandColor(name: "Surface", hex: "#1A1A1E", role: .surface),
                BrandColor(name: "White", hex: "#FFFFFF", role: .custom)
            ],
            logos: [
                BrandLogo(name: "\(name) Icon", type: .systemSymbol, systemSymbol: iconSymbol, accentColorHex: accentHex)
            ]
        )
        brands.append(newBrand)
        selectedBrandId = newBrand.id
        saveBrands()
        generateMissingPresetImages()
        showToast(message: "Created brand '\(name)'")
    }

    public func updateBrand(_ brand: Brand) {
        if let idx = brands.firstIndex(where: { $0.id == brand.id }) {
            brands[idx] = brand
            saveBrands()
        }
    }

    public func deleteBrand(_ brand: Brand) {
        brands.removeAll(where: { $0.id == brand.id })
        if selectedBrandId == brand.id {
            selectedBrandId = brands.first?.id
        }
        saveBrands()
        showToast(message: "Deleted brand '\(brand.name)'")
    }

    public func addColor(to brand: Brand, name: String, hex: String, role: ColorRole = .custom) {
        guard let idx = brands.firstIndex(where: { $0.id == brand.id }) else { return }
        let color = BrandColor(name: name, hex: hex, role: role)
        brands[idx].colors.append(color)
        saveBrands()
        showToast(message: "Added color '\(name)' (\(color.formattedHex))")
    }

    public func updateColor(in brand: Brand, color: BrandColor) {
        guard let bIdx = brands.firstIndex(where: { $0.id == brand.id }),
              let cIdx = brands[bIdx].colors.firstIndex(where: { $0.id == color.id }) else { return }
        brands[bIdx].colors[cIdx] = color
        saveBrands()
    }

    public func deleteColor(from brand: Brand, colorId: UUID) {
        guard let bIdx = brands.firstIndex(where: { $0.id == brand.id }) else { return }
        brands[bIdx].colors.removeAll(where: { $0.id == colorId })
        saveBrands()
    }

    public func addLogoFile(to brand: Brand, fileURL: URL, name: String? = nil) {
        guard let bIdx = brands.firstIndex(where: { $0.id == brand.id }) else { return }

        let ext = fileURL.pathExtension.isEmpty ? "png" : fileURL.pathExtension
        let id = UUID()
        let destFileName = "\(id.uuidString).\(ext)"
        let destURL = assetsDirectoryURL.appendingPathComponent(destFileName)

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: fileURL, to: destURL)

            let logoName = name ?? fileURL.deletingPathExtension().lastPathComponent
            let newLogo = BrandLogo(
                id: id,
                name: logoName,
                type: .file,
                fileName: destFileName,
                isDarkVariant: false
            )
            brands[bIdx].logos.append(newLogo)
            saveBrands()
            showToast(message: "Imported logo '\(logoName)'")
        } catch {
            print("Failed to import logo: \(error)")
        }
    }

    public func addSymbolLogo(to brand: Brand, name: String, symbol: String, accentHex: String?) {
        guard let bIdx = brands.firstIndex(where: { $0.id == brand.id }) else { return }
        let id = UUID()
        let fileName = "\(id.uuidString).png"
        let destURL = assetsDirectoryURL.appendingPathComponent(fileName)

        if let img = renderSymbolToImage(symbol: symbol, accentHex: accentHex) {
            if let tiff = img.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: destURL)
            }
        }

        let newLogo = BrandLogo(
            id: id,
            name: name,
            type: .systemSymbol,
            fileName: fileName,
            systemSymbol: symbol,
            accentColorHex: accentHex
        )
        brands[bIdx].logos.append(newLogo)
        saveBrands()
        showToast(message: "Added symbol logo '\(name)'")
    }

    public func deleteLogo(from brand: Brand, logoId: UUID) {
        guard let bIdx = brands.firstIndex(where: { $0.id == brand.id }) else { return }
        if let logo = brands[bIdx].logos.first(where: { $0.id == logoId }),
           let fileName = logo.fileName {
            let fileURL = assetsDirectoryURL.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        brands[bIdx].logos.removeAll(where: { $0.id == logoId })
        saveBrands()
    }

    // MARK: - Default Presets

    private func defaultPresetBrands() -> [Brand] {
        return [
            Brand(
                name: "Apple",
                tagline: "Design System & Platform",
                iconSymbol: "apple.logo",
                accentColorHex: "#0071E3",
                colors: [
                    BrandColor(name: "Apple Blue", hex: "#0071E3", role: .primary),
                    BrandColor(name: "Space Black", hex: "#1D1D1F", role: .surface),
                    BrandColor(name: "Pure White", hex: "#FFFFFF", role: .background),
                    BrandColor(name: "Silver Gray", hex: "#F5F5F7", role: .secondary),
                    BrandColor(name: "Space Gray", hex: "#86868B", role: .accent),
                    BrandColor(name: "Cupertino Green", hex: "#30D158", role: .accent),
                    BrandColor(name: "Electric Rose", hex: "#FF375F", role: .accent)
                ],
                logos: [
                    BrandLogo(name: "Apple Logo", type: .systemSymbol, systemSymbol: "apple.logo", accentColorHex: "#FFFFFF"),
                    BrandLogo(name: "Swift Mark", type: .systemSymbol, systemSymbol: "swift", accentColorHex: "#F05138"),
                    BrandLogo(name: "App Store", type: .systemSymbol, systemSymbol: "bag.fill", accentColorHex: "#0071E3"),
                    BrandLogo(name: "Finder Face", type: .systemSymbol, systemSymbol: "macwindow", accentColorHex: "#0071E3")
                ],
                isFavorite: true
            ),
            Brand(
                name: "Open Island",
                tagline: "AI Dynamic Island System",
                iconSymbol: "capsule.fill",
                accentColorHex: "#FF5E5B",
                colors: [
                    BrandColor(name: "Coral Pulse", hex: "#FF5E5B", role: .primary),
                    BrandColor(name: "Island Ink", hex: "#0D0D0F", role: .surface),
                    BrandColor(name: "Paper Canvas", hex: "#F1EAD9", role: .background),
                    BrandColor(name: "Agent Mint", hex: "#00E599", role: .accent),
                    BrandColor(name: "Vibe Violet", hex: "#8B5CF6", role: .accent),
                    BrandColor(name: "Electric Blue", hex: "#3B82F6", role: .secondary)
                ],
                logos: [
                    BrandLogo(name: "Dynamic Island", type: .systemSymbol, systemSymbol: "capsule.portrait.fill", accentColorHex: "#FF5E5B"),
                    BrandLogo(name: "Agent Terminal", type: .systemSymbol, systemSymbol: "terminal.fill", accentColorHex: "#00E599"),
                    BrandLogo(name: "Wave Pulse", type: .systemSymbol, systemSymbol: "waveform.path.ecg", accentColorHex: "#3B82F6")
                ],
                isFavorite: true
            ),
            Brand(
                name: "Stripe",
                tagline: "Financial Infrastructure",
                iconSymbol: "creditcard.fill",
                accentColorHex: "#635BFF",
                colors: [
                    BrandColor(name: "Stripe Blurple", hex: "#635BFF", role: .primary),
                    BrandColor(name: "Slate Navy", hex: "#0A2540", role: .surface),
                    BrandColor(name: "Mint Turquoise", hex: "#00D4B2", role: .accent),
                    BrandColor(name: "Cyan Gradient", hex: "#6392F9", role: .secondary),
                    BrandColor(name: "Off White", hex: "#F6F9FC", role: .background)
                ],
                logos: [
                    BrandLogo(name: "Stripe S", type: .systemSymbol, systemSymbol: "dollarsign.circle.fill", accentColorHex: "#635BFF"),
                    BrandLogo(name: "Terminal Card", type: .systemSymbol, systemSymbol: "creditcard.fill", accentColorHex: "#00D4B2"),
                    BrandLogo(name: "API Code", type: .systemSymbol, systemSymbol: "chevron.left.forwardslash.chevron.right", accentColorHex: "#6392F9")
                ],
                isFavorite: true
            ),
            Brand(
                name: "Figma",
                tagline: "Collaborative Interface Design",
                iconSymbol: "paintbrush.fill",
                accentColorHex: "#A259FF",
                colors: [
                    BrandColor(name: "Figma Violet", hex: "#A259FF", role: .primary),
                    BrandColor(name: "Figma Red", hex: "#F24E1E", role: .secondary),
                    BrandColor(name: "Figma Green", hex: "#0ACF83", role: .accent),
                    BrandColor(name: "Figma Sky Blue", hex: "#1ABCFE", role: .accent),
                    BrandColor(name: "Figma Salmon", hex: "#FF7262", role: .accent)
                ],
                logos: [
                    BrandLogo(name: "Vector Pen", type: .systemSymbol, systemSymbol: "pencil.and.outline", accentColorHex: "#A259FF"),
                    BrandLogo(name: "Components", type: .systemSymbol, systemSymbol: "square.grid.2x2.fill", accentColorHex: "#0ACF83"),
                    BrandLogo(name: "Bezier Path", type: .systemSymbol, systemSymbol: "beziercurve", accentColorHex: "#1ABCFE")
                ],
                isFavorite: false
            ),
            Brand(
                name: "Linear",
                tagline: "Purpose-Built Product Tool",
                iconSymbol: "triangle.fill",
                accentColorHex: "#5E6AD2",
                colors: [
                    BrandColor(name: "Linear Indigo", hex: "#5E6AD2", role: .primary),
                    BrandColor(name: "Deep Obsidian", hex: "#14151B", role: .surface),
                    BrandColor(name: "Muted Steel", hex: "#717789", role: .secondary),
                    BrandColor(name: "Pure Glow", hex: "#FFFFFF", role: .accent)
                ],
                logos: [
                    BrandLogo(name: "Linear Cycle", type: .systemSymbol, systemSymbol: "arrow.triangle.2.circlepath", accentColorHex: "#5E6AD2"),
                    BrandLogo(name: "Issue Scope", type: .systemSymbol, systemSymbol: "target", accentColorHex: "#FFFFFF")
                ],
                isFavorite: false
            )
        ]
    }
}
