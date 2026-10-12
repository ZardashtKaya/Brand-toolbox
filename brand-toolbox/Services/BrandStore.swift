import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

@MainActor
public final class BrandStore: ObservableObject {
    public static let shared = BrandStore()

    @Published public var brands: [Brand] = []
    @Published public var selectedBrandId: UUID?
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
        let dir = paths[0].appendingPathComponent("BrandingToolbox", isDirectory: true)
        let legacyDir = paths[0].appendingPathComponent("BrandToolbox", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            if fileManager.fileExists(atPath: legacyDir.path) {
                try? fileManager.moveItem(at: legacyDir, to: dir)
            } else {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
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

    public func idealDockHeight(maxAllowed: CGFloat = 560) -> CGFloat {
        guard let brand = selectedBrand else { return 280 }
        let colorsCount = max(1, brand.colors.count)
        let logosCount = max(1, brand.logos.count + 1)
        let fontsCount = brand.fonts.count

        let colorsHeight = CGFloat(colorsCount) * 32
        let logoRows = ceil(Double(logosCount) / 2.0)
        let logosHeight = CGFloat(max(1, logoRows)) * 56
        let fontsHeight = fontsCount > 0 ? (CGFloat(fontsCount) * 30 + 26) : 0
        let chromeHeight: CGFloat = 142 // Header + Brand chips + Section headers + Dividers + Padding
        let total = chromeHeight + colorsHeight + logosHeight + fontsHeight

        let minHeight: CGFloat = 260
        let maxHeight = min(maxAllowed, 560)
        return min(maxHeight, max(minHeight, total))
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
                var loaded = try JSONDecoder().decode([Brand].self, from: data)
                if !loaded.isEmpty {
                    // Seed fonts & SVG logos for preset brands if missing
                    let presets = defaultPresetBrands()
                    for i in 0..<loaded.count {
                        if let match = presets.first(where: { $0.name == loaded[i].name }) {
                            if loaded[i].fonts.isEmpty {
                                loaded[i].fonts = match.fonts
                            }
                            for presetLogo in match.logos where presetLogo.isSVG {
                                if !loaded[i].logos.contains(where: { $0.name == presetLogo.name || $0.fileName == presetLogo.fileName }) {
                                    loaded[i].logos.append(presetLogo)
                                }
                            }
                        }
                    }
                    self.brands = loaded
                    if selectedBrandId == nil || !loaded.contains(where: { $0.id == selectedBrandId }) {
                        self.selectedBrandId = loaded.first?.id
                    }
                    saveBrands()
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

    public func isSVGLogo(_ logo: BrandLogo) -> Bool {
        if logo.isSVG { return true }
        if let fileURL = fileURLForLogo(logo), fileURL.pathExtension.lowercased() == "svg" {
            return true
        }
        return false
    }

    public func svgContentForLogo(_ logo: BrandLogo) -> String? {
        guard let fileURL = fileURLForLogo(logo), fileURL.pathExtension.lowercased() == "svg" else {
            return nil
        }
        return try? String(contentsOf: fileURL, encoding: .utf8)
    }

    public func copySVGCode(_ logo: BrandLogo) {
        guard let svg = svgContentForLogo(logo) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(svg, forType: .string)
        showToast(message: "Copied SVG code for '\(logo.name)'")

        if soundAndHaptics {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .now
            )
            NSSound(named: "Tink")?.play()
        }
    }

    public func copyLogoImage(_ logo: BrandLogo) {
        let isSVG = isSVGLogo(logo)
        let svgString = isSVG ? svgContentForLogo(logo) : nil
        let fileURL = fileURLForLogo(logo)
        let image = imageForLogo(logo)

        NSPasteboard.general.clearContents()
        var wroteSomething = false

        if let svg = svgString, let data = svg.data(using: .utf8) {
            let svgType = NSPasteboard.PasteboardType("public.svg-image")
            let svgXmlType = NSPasteboard.PasteboardType("image/svg+xml")
            let fileURLType = NSPasteboard.PasteboardType("public.file-url")

            var types: [NSPasteboard.PasteboardType] = [svgType, svgXmlType, .string]
            if image?.tiffRepresentation != nil {
                types.append(.tiff)
            }
            if fileURL != nil {
                types.append(fileURLType)
            }

            NSPasteboard.general.declareTypes(types, owner: nil)
            NSPasteboard.general.setData(data, forType: svgType)
            NSPasteboard.general.setData(data, forType: svgXmlType)
            NSPasteboard.general.setString(svg, forType: .string)
            if let img = image, let tiff = img.tiffRepresentation {
                NSPasteboard.general.setData(tiff, forType: .tiff)
            }
            if let fileURL = fileURL {
                NSPasteboard.general.setString(fileURL.absoluteString, forType: fileURLType)
                (fileURL as NSURL).write(to: NSPasteboard.general)
            }
            wroteSomething = true
            showToast(message: "Copied SVG '\(logo.name)' to clipboard")
        } else if let image = image {
            NSPasteboard.general.writeObjects([image])
            if let fileURL = fileURL {
                (fileURL as NSURL).write(to: NSPasteboard.general)
            }
            wroteSomething = true
            showToast(message: "Copied '\(logo.name)' to clipboard")
        }

        guard wroteSomething else { return }

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
                if img.size.width <= 0 || img.size.height <= 0 {
                    img.size = NSSize(width: 128, height: 128)
                }
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
                if let fileName = logo.fileName, fileName.hasSuffix(".svg") {
                    let targetURL = assetsDirectoryURL.appendingPathComponent(fileName)
                    if !fileManager.fileExists(atPath: targetURL.path) {
                        if let svg = defaultSVGContent(for: fileName, brand: brand, logo: logo) {
                            try? svg.write(to: targetURL, atomically: true, encoding: .utf8)
                        }
                    }
                } else if logo.fileName == nil && logo.systemSymbol != nil {
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

    private func defaultSVGContent(for fileName: String, brand: Brand, logo: BrandLogo) -> String? {
        let name = logo.name.lowercased()
        if brand.name == "Apple" || name.contains("apple") {
            return """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
              <rect width="100" height="100" rx="22" fill="#1D1D1F"/>
              <path fill="#0071E3" d="M73.5 68.3c-1.4 3.2-3 6.1-4.9 8.8-2.6 3.7-4.7 6.2-6.3 7.6-2.5 2.3-5.2 3.5-8.1 3.6-2.1 0-4.6-.6-7.5-1.8-2.9-1.2-5.6-1.8-8.1-1.8-2.6 0-5.3.6-8.3 1.8-3 1.2-5.3 1.8-7.1 1.9-2.4.1-5.1-1.1-8.1-3.4-2.1-1.7-4.4-4.5-7-8.4-3.5-5.3-6.2-11.3-8.3-18.1-2.1-6.8-3.1-13.2-3.1-19.1 0-8.1 2-14.7 6-19.9 4-5.2 9-7.9 15.1-8 2.7 0 5.8.8 9.4 2.3 3.6 1.5 5.8 2.3 6.5 2.4.9-.1 3.2-1 7-2.5 3.7-1.5 6.9-2.2 9.6-2 7.4.4 13.2 3.2 17.5 8.4-6.4 3.9-9.6 9.2-9.5 16 .1 5.3 2.2 9.7 6.2 13.3 4.1 3.6 8.8 5.7 14.4 6.3-1.2 3.7-2.6 7.3-4.1 10.7zM56 12.8c0-4.3 1.6-8.4 4.7-12.3 3.1-3.8 6.9-6.1 11.4-6.7.1.8.2 1.6.2 2.3 0 4.3-1.6 8.5-4.9 12.4-3.2 3.9-7.1 6.1-11.6 6.6-.1-.8-.2-1.6-.2-2.3z"/>
            </svg>
            """
        } else if brand.name == "Open Island" || name.contains("island") {
            return """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 40" width="120" height="40">
              <rect x="0" y="0" width="120" height="40" rx="20" fill="#0D0D0F"/>
              <rect x="1.5" y="1.5" width="117" height="37" rx="18.5" fill="none" stroke="#FF5E5B" stroke-width="1.5"/>
              <circle cx="24" cy="20" r="8" fill="#FF5E5B"/>
              <rect x="40" y="16" width="46" height="8" rx="4" fill="#FFFFFF" fill-opacity="0.85"/>
              <circle cx="98" cy="20" r="5" fill="#00E599"/>
            </svg>
            """
        } else if brand.name == "Stripe" || name.contains("stripe") {
            return """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
              <rect width="100" height="100" rx="22" fill="#635BFF"/>
              <path fill="#FFFFFF" d="M50 35c0-3.5 3-5 8-5 7 0 16 2.5 23 6V18c-7.5-3-15-4-23-4-18 0-30 9.5-30 25.5 0 25 34 21 34 31.5 0 4.2-3.8 5.5-9 5.5-8 0-18.5-3.5-26-7.5v18.5c8.5 3.5 17 5 26 5 19 0 32-9 32-26C85 41 50 45.5 50 35z"/>
            </svg>
            """
        } else if brand.name == "Figma" || name.contains("figma") {
            return """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 70 100" width="70" height="100">
              <path fill="#F24E1E" d="M17 0h36a17 17 0 0 1 0 34H17a17 17 0 0 1 0-34z"/>
              <path fill="#A259FF" d="M17 33h36a17 17 0 0 1 0 34H17a17 17 0 0 1 0-34z"/>
              <path fill="#1ABCFE" d="M53 33a17 17 0 1 1 0 34 17 17 0 0 1 0-34z"/>
              <path fill="#0ACF83" d="M17 66h18v17a17 17 0 1 1-18-17z"/>
              <path fill="#FF7262" d="M17 0a17 17 0 0 0 0 34h18V0H17z"/>
            </svg>
            """
        } else if brand.name == "Linear" || name.contains("linear") {
            return """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
              <rect width="100" height="100" rx="22" fill="#14151B"/>
              <path fill="#5E6AD2" d="M50 20A30 30 0 1 0 80 50 30 30 0 0 0 50 20zm0 48A18 18 0 1 1 68 50 18 18 0 0 1 50 68z"/>
              <polygon fill="#FFFFFF" points="45,38 62,50 45,62"/>
            </svg>
            """
        }
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
          <circle cx="50" cy="50" r="44" fill="\(brand.accentColorHex)"/>
          <text x="50" y="58" font-size="28" font-weight="bold" fill="#FFFFFF" text-anchor="middle">\(brand.name.prefix(2).uppercased())</text>
        </svg>
        """
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

    public func addColors(to brand: Brand, colors: [(name: String, hex: String, role: ColorRole)]) {
        guard let idx = brands.firstIndex(where: { $0.id == brand.id }), !colors.isEmpty else { return }
        for item in colors {
            let color = BrandColor(name: item.name, hex: item.hex, role: item.role)
            brands[idx].colors.append(color)
        }
        saveBrands()
        let count = colors.count
        showToast(message: "Added \(count) color\(count == 1 ? "" : "s") to '\(brand.name)'")
        if soundAndHaptics {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .now
            )
            NSSound(named: "Glass")?.play()
        }
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

    public func addLogoImage(to brand: Brand, image: NSImage, name: String? = nil) {
        guard let bIdx = brands.firstIndex(where: { $0.id == brand.id }) else { return }

        let id = UUID()
        let destFileName = "\(id.uuidString).png"
        let destURL = assetsDirectoryURL.appendingPathComponent(destFileName)

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        do {
            try pngData.write(to: destURL)
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let logoName = !trimmed.isEmpty ? trimmed : "\(brand.name) Logo \(brands[bIdx].logos.count + 1)"
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
            if soundAndHaptics {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                NSSound(named: "Pop")?.play()
            }
        } catch {
            print("Failed to save dropped image: \(error)")
        }
    }

    public func addLogoSVGData(to brand: Brand, data: Data, name: String? = nil) {
        guard let bIdx = brands.firstIndex(where: { $0.id == brand.id }) else { return }

        let id = UUID()
        let destFileName = "\(id.uuidString).svg"
        let destURL = assetsDirectoryURL.appendingPathComponent(destFileName)

        do {
            try data.write(to: destURL)
            let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let logoName = !trimmed.isEmpty ? trimmed : "\(brand.name) Vector Logo \(brands[bIdx].logos.count + 1)"
            let newLogo = BrandLogo(
                id: id,
                name: logoName,
                type: .file,
                fileName: destFileName,
                isDarkVariant: false
            )
            brands[bIdx].logos.append(newLogo)
            saveBrands()
            showToast(message: "Imported SVG logo '\(logoName)'")
            if soundAndHaptics {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                NSSound(named: "Pop")?.play()
            }
        } catch {
            print("Failed to save dropped SVG: \(error)")
        }
    }

    // MARK: - Universal Drag & Drop Intake
    @discardableResult
    public func handleDroppedProviders(_ providers: [NSItemProvider], for brand: Brand) -> Bool {
        guard !providers.isEmpty else { return false }
        var handled = false

        for provider in providers {
            // 1. Finder / local file URLs
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var fileURL: URL? = nil
                    if let url = item as? URL {
                        fileURL = url
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        fileURL = url
                    }
                    if let fileURL = fileURL {
                        Task { @MainActor in
                            self.addLogoFile(to: brand, fileURL: fileURL)
                        }
                    }
                }
                handled = true
                continue
            }

            // 2. Direct SVG data
            if provider.hasItemConformingToTypeIdentifier(UTType.svg.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.svg.identifier) { data, _ in
                    if let data = data {
                        Task { @MainActor in
                            self.addLogoSVGData(to: brand, data: data, name: provider.suggestedName)
                        }
                    }
                }
                handled = true
                continue
            }

            // 3. Plain text containing SVG XML
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    if let str = item as? String, str.contains("<svg") && str.contains("</svg>"),
                       let data = str.data(using: .utf8) {
                        Task { @MainActor in
                            self.addLogoSVGData(to: brand, data: data, name: provider.suggestedName ?? "Vector Icon")
                        }
                    }
                }
            }

            // 4. Direct NSImage instances (from Figma, Photos, Arc/Safari)
            if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { object, _ in
                    if let image = object as? NSImage {
                        Task { @MainActor in
                            self.addLogoImage(to: brand, image: image, name: provider.suggestedName)
                        }
                    }
                }
                handled = true
                continue
            }

            // 5. Image data representations (PNG, JPEG, TIFF, general image)
            let imageTypes: [UTType] = [.png, .jpeg, .tiff, .image]
            for type in imageTypes {
                if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                        if let data = data, let image = NSImage(data: data) {
                            Task { @MainActor in
                                self.addLogoImage(to: brand, image: image, name: provider.suggestedName)
                            }
                        }
                    }
                    handled = true
                    break
                }
            }
        }

        return handled
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

    // MARK: - Fonts Management

    public func addFont(to brand: Brand, name: String, role: String = "Primary") {
        guard let bIdx = brands.firstIndex(where: { $0.id == brand.id }) else { return }
        let font = BrandFont(name: name, role: role)
        brands[bIdx].fonts.append(font)
        saveBrands()
        showToast(message: "Added font '\(name)'")
    }

    public func deleteFont(from brand: Brand, fontId: UUID) {
        guard let bIdx = brands.firstIndex(where: { $0.id == brand.id }) else { return }
        brands[bIdx].fonts.removeAll(where: { $0.id == fontId })
        saveBrands()
    }

    public func copyFontName(_ font: BrandFont) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(font.name, forType: .string)
        showToast(message: "Copied font '\(font.name)'")
        if soundAndHaptics {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            NSSound(named: "Tink")?.play()
        }
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
                    BrandLogo(name: "Apple Vector (SVG)", type: .file, fileName: "apple_mark.svg", accentColorHex: "#0071E3"),
                    BrandLogo(name: "Apple Logo", type: .systemSymbol, systemSymbol: "apple.logo", accentColorHex: "#FFFFFF"),
                    BrandLogo(name: "Swift Mark", type: .systemSymbol, systemSymbol: "swift", accentColorHex: "#F05138"),
                    BrandLogo(name: "App Store", type: .systemSymbol, systemSymbol: "bag.fill", accentColorHex: "#0071E3"),
                    BrandLogo(name: "Finder Face", type: .systemSymbol, systemSymbol: "macwindow", accentColorHex: "#0071E3")
                ],
                fonts: [
                    BrandFont(name: "SF Pro", role: "Primary"),
                    BrandFont(name: "SF Pro Rounded", role: "Headings"),
                    BrandFont(name: "SF Mono", role: "Code"),
                    BrandFont(name: "New York", role: "Serif")
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
                    BrandLogo(name: "Island Vector (SVG)", type: .file, fileName: "open_island.svg", accentColorHex: "#FF5E5B"),
                    BrandLogo(name: "Dynamic Island", type: .systemSymbol, systemSymbol: "capsule.portrait.fill", accentColorHex: "#FF5E5B"),
                    BrandLogo(name: "Agent Terminal", type: .systemSymbol, systemSymbol: "terminal.fill", accentColorHex: "#00E599"),
                    BrandLogo(name: "Wave Pulse", type: .systemSymbol, systemSymbol: "waveform.path.ecg", accentColorHex: "#3B82F6")
                ],
                fonts: [
                    BrandFont(name: "Geist", role: "Primary"),
                    BrandFont(name: "JetBrains Mono", role: "Code")
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
                    BrandLogo(name: "Stripe S (SVG)", type: .file, fileName: "stripe_s.svg", accentColorHex: "#635BFF"),
                    BrandLogo(name: "Stripe S", type: .systemSymbol, systemSymbol: "dollarsign.circle.fill", accentColorHex: "#635BFF"),
                    BrandLogo(name: "Terminal Card", type: .systemSymbol, systemSymbol: "creditcard.fill", accentColorHex: "#00D4B2"),
                    BrandLogo(name: "API Code", type: .systemSymbol, systemSymbol: "chevron.left.forwardslash.chevron.right", accentColorHex: "#6392F9")
                ],
                fonts: [
                    BrandFont(name: "Söhne", role: "Primary"),
                    BrandFont(name: "Söhne Breit", role: "Headings"),
                    BrandFont(name: "Söhne Mono", role: "Code")
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
                    BrandLogo(name: "Figma Vector (SVG)", type: .file, fileName: "figma_mark.svg", accentColorHex: "#A259FF"),
                    BrandLogo(name: "Vector Pen", type: .systemSymbol, systemSymbol: "pencil.and.outline", accentColorHex: "#A259FF"),
                    BrandLogo(name: "Components", type: .systemSymbol, systemSymbol: "square.grid.2x2.fill", accentColorHex: "#0ACF83"),
                    BrandLogo(name: "Bezier Path", type: .systemSymbol, systemSymbol: "beziercurve", accentColorHex: "#1ABCFE")
                ],
                fonts: [
                    BrandFont(name: "Inter", role: "Primary"),
                    BrandFont(name: "Whyte Inktrap", role: "Display")
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
                    BrandLogo(name: "Linear Cycle (SVG)", type: .file, fileName: "linear_mark.svg", accentColorHex: "#5E6AD2"),
                    BrandLogo(name: "Linear Cycle", type: .systemSymbol, systemSymbol: "arrow.triangle.2.circlepath", accentColorHex: "#5E6AD2"),
                    BrandLogo(name: "Issue Scope", type: .systemSymbol, systemSymbol: "target", accentColorHex: "#FFFFFF")
                ],
                fonts: [
                    BrandFont(name: "Inter", role: "Primary"),
                    BrandFont(name: "Fragment Mono", role: "Code")
                ],
                isFavorite: false
            )
        ]
    }
}
