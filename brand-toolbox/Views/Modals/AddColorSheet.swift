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
            HStack(spacing: 12) {
                Button("Cancel") {
                    onClose?()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

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
    }
}

// MARK: - Previews

#Preview("Add Color Sheet") {
    AddColorSheet(store: .shared, brand: .mock)
}
