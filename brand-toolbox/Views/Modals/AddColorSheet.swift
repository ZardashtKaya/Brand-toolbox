import SwiftUI

public struct AddColorSheet: View {
    @ObservedObject var store: BrandStore
    public let brand: Brand
    public var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var hexInput: String = "#0071E3"
    @State private var selectedColor: Color = Color(hex: "#0071E3")
    @State private var selectedRole: ColorRole = .accent
    @State private var isProgrammaticUpdate: Bool = false
    @State private var clipboardColorCount: Int = 0
    @State private var statusMessage: String? = nil
    @State private var isErrorStatus: Bool = false

    private let presetHexes = [
        "#0071E3", "#000000", "#FFFFFF", "#FF5E5B",
        "#635BFF", "#A259FF", "#0ACF83", "#F59E0B",
        "#86868B", "#1D1D1F", "#30D158", "#3B82F6"
    ]

    public init(store: BrandStore = .shared, brand: Brand, onClose: (() -> Void)? = nil) {
        self.store = store
        self.brand = brand
        self.onClose = onClose
    }

    private var contrastTextColor: Color {
        let nsColor = NSColor(selectedColor)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance < 0.55 ? .white : .black
    }

    private func cleanHex(_ string: String) -> String {
        var clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }
        return clean
    }

    private func isCompleteValidHex(_ string: String) -> Bool {
        let clean = cleanHex(string)
        guard clean.count == 3 || clean.count == 6 || clean.count == 8 else {
            return false
        }
        let hexDigits = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        return clean.unicodeScalars.allSatisfy { hexDigits.contains($0) }
    }

    private struct ExtractedColor {
        let name: String
        let hex: String
    }

    private func normalizeExtractedHex(_ raw: String) -> String {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if clean.hasPrefix("#") { clean.removeFirst() }
        else if clean.hasPrefix("0X") { clean.removeFirst(2) }
        if clean.count == 3 {
            clean = clean.map { "\($0)\($0)" }.joined()
        }
        return "#" + clean
    }

    private func cleanExtractedName(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`$;,:- \t\n\r"))
        if s.hasPrefix("--") { s.removeFirst(2) }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`$;,:- \t\n\r"))
        s = s.replacingOccurrences(of: "[-_]+", with: " ", options: .regularExpression)
        let words = s.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
        return words.joined(separator: " ")
    }

    private func extractColors(from text: String) -> [ExtractedColor] {
        var results: [ExtractedColor] = []
        var seenHexes = Set<String>()

        let lines = text.components(separatedBy: .newlines)
        let namedRegex = try? NSRegularExpression(
            pattern: #"["'`]?([a-zA-Z0-9_\-\s]{1,40})["'`]?\s*[:=-]\s*["'`\s]*(?:#|0x)([0-9a-fA-F]{3,8})\b"#,
            options: .caseInsensitive
        )
        let hexRegex = try? NSRegularExpression(
            pattern: #"(?:#|0x)([0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b"#,
            options: .caseInsensitive
        )

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let nsLine = trimmed as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)

            if let namedRegex = namedRegex {
                let matches = namedRegex.matches(in: trimmed, options: [], range: fullRange)
                for match in matches where match.numberOfRanges >= 3 {
                    let nameRange = match.range(at: 1)
                    let hexRange = match.range(at: 2)
                    let rawName = nsLine.substring(with: nameRange)
                    let rawHex = nsLine.substring(with: hexRange)
                    let cleanedName = cleanExtractedName(rawName)
                    let normHex = normalizeExtractedHex(rawHex)

                    if !seenHexes.contains(normHex) {
                        seenHexes.insert(normHex)
                        let finalName = cleanedName.isEmpty ? "Color \(normHex)" : cleanedName
                        results.append(ExtractedColor(name: finalName, hex: normHex))
                    }
                }
            }

            if let hexRegex = hexRegex {
                let matches = hexRegex.matches(in: trimmed, options: [], range: fullRange)
                for match in matches where match.numberOfRanges >= 2 {
                    let hexRange = match.range(at: 1)
                    let rawHex = nsLine.substring(with: hexRange)
                    let normHex = normalizeExtractedHex(rawHex)

                    if !seenHexes.contains(normHex) {
                        seenHexes.insert(normHex)
                        results.append(ExtractedColor(name: "Color \(normHex)", hex: normHex))
                    }
                }
            }
        }

        // Fallback: standalone 6-character hex tokens with at least one digit
        if results.isEmpty {
            let rawTokenRegex = try? NSRegularExpression(pattern: #"\b([0-9a-fA-F]{6})\b"#, options: .caseInsensitive)
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            let matches = rawTokenRegex?.matches(in: text, options: [], range: fullRange) ?? []
            for match in matches where match.numberOfRanges >= 2 {
                let hex = nsText.substring(with: match.range(at: 1))
                if hex.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
                    let normHex = "#" + hex.uppercased()
                    if !seenHexes.contains(normHex) {
                        seenHexes.insert(normHex)
                        results.append(ExtractedColor(name: "Color \(normHex)", hex: normHex))
                    }
                }
            }
        }

        return results
    }

    private func scanClipboardPreview() {
        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            let colors = extractColors(from: text)
            clipboardColorCount = colors.count
        }
    }

    private func autoAddColorsFromClipboard() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string),
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "Clipboard is empty. Copy some hex codes first."
            isErrorStatus = true
            return
        }

        let extracted = extractColors(from: clipboardText)
        guard !extracted.isEmpty else {
            statusMessage = "No hex colors found in clipboard. Copy hex codes (e.g. #0071E3, #FF5E5B) and try again."
            isErrorStatus = true
            return
        }

        // Filter out colors that already exist in brand palette
        let existingHexes = Set(brand.colors.map { $0.formattedHex.uppercased() })
        let newColors = extracted.filter { !existingHexes.contains($0.hex.uppercased()) }

        if newColors.isEmpty {
            statusMessage = "All \(extracted.count) color\(extracted.count == 1 ? "" : "s") found in clipboard already exist in \(brand.name)."
            isErrorStatus = false
            return
        }

        store.addColors(to: brand, colors: newColors.map { ($0.name, $0.hex, selectedRole) })
        onClose?()
        dismiss()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Color • \(brand.name)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.15))
                    Text("Add a hex color to \(brand.name)'s palette")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.48))
                }
                Spacer()
                Button(action: {
                    onClose?()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color.black.opacity(0.25))
                }
                .buttonStyle(.plain)
            }

            // Auto Add Colors Quick-Action
            Button(action: autoAddColorsFromClipboard) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(brand.accentColor)

                    Text("Auto Add Colors from Clipboard")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.18))

                    Spacer()

                    if clipboardColorCount > 0 {
                        Text("\(clipboardColorCount) detected")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(brand.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(brand.accentColor.opacity(0.12))
                            .cornerRadius(4)
                    }

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(brand.accentColor.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.96, green: 0.96, blue: 0.98))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(brand.accentColor.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Scan clipboard with regex to automatically extract and add all hex colors to \(brand.name)")

            if let msg = statusMessage {
                HStack(spacing: 6) {
                    Image(systemName: isErrorStatus ? "exclamationmark.circle.fill" : "info.circle.fill")
                        .foregroundColor(isErrorStatus ? .orange : .blue)
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundColor(isErrorStatus ? Color(red: 0.7, green: 0.25, blue: 0.1) : Color(red: 0.2, green: 0.35, blue: 0.6))
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isErrorStatus ? Color.orange.opacity(0.1) : Color.blue.opacity(0.08))
                .cornerRadius(6)
            }

            // Preview Swatch
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selectedColor)
                    .frame(height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: selectedColor.opacity(0.35), radius: 8, x: 0, y: 3)

                VStack(spacing: 3) {
                    Text(name.isEmpty ? "Color Name" : name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(contrastTextColor)

                    Text(hexInput.uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(contrastTextColor.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity)

            // Form Inputs
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Color Name")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))
                    TextField("e.g. Electric Blue, Dark Slate, Neon Lime", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Hex Code")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))
                        TextField("#HEX", text: $hexInput)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .font(.system(size: 12, design: .monospaced))
                            .onChange(of: hexInput) { newHex in
                                if isCompleteValidHex(newHex) {
                                    let clean = cleanHex(newHex)
                                    let formatted = "#" + clean
                                    let newColor = Color(hex: formatted)
                                    if newColor != selectedColor {
                                        isProgrammaticUpdate = true
                                        selectedColor = newColor
                                        isProgrammaticUpdate = false
                                    }
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Picker")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))
                        ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: selectedColor) { newColor in
                                guard !isProgrammaticUpdate else { return }
                                hexInput = newColor.toHex()
                            }
                            .frame(height: 22)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Role")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))
                        Picker("", selection: $selectedRole) {
                            ForEach(ColorRole.allCases) { role in
                                Text(role.rawValue).tag(role)
                            }
                        }
                        .labelsHidden()
                    }
                }

                // Presets
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick Presets")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))

                    HStack(spacing: 8) {
                        ForEach(presetHexes, id: \.self) { hex in
                            let isPicked = hexInput.uppercased() == hex.uppercased()
                            Button(action: {
                                isProgrammaticUpdate = true
                                hexInput = hex
                                selectedColor = Color(hex: hex)
                                isProgrammaticUpdate = false
                            }) {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(isPicked ? Color.black : Color.black.opacity(0.15), lineWidth: isPicked ? 2.2 : 0.8)
                                    )
                                    .shadow(color: Color(hex: hex).opacity(0.3), radius: isPicked ? 3 : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Action Buttons
            HStack(spacing: 10) {
                Button("Cancel") {
                    onClose?()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: autoAddColorsFromClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                        Text("Auto Add Colors")
                    }
                }
                .buttonStyle(.bordered)
                .help("Automatically extracts all hex colors from your clipboard using regex and adds them to \(brand.name)")

                Button("Add Color") {
                    let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !finalName.isEmpty && isCompleteValidHex(hexInput) else { return }
                    let clean = cleanHex(hexInput)
                    let formattedHex = "#" + clean.uppercased()
                    store.addColor(
                        to: brand,
                        name: finalName,
                        hex: formattedHex,
                        role: selectedRole
                    )
                    onClose?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(brand.accentColor)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isCompleteValidHex(hexInput))
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(width: 380)
        .background(Color.white)
        .onAppear {
            scanClipboardPreview()
        }
    }
}

// MARK: - Previews

#Preview("Add Color Sheet") {
    AddColorSheet(store: .shared, brand: .mock)
}
