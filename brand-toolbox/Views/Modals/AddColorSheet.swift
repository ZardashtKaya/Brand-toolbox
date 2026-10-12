import SwiftUI

public struct AddColorSheet: View {
    @ObservedObject var store: BrandStore
    public let brand: Brand
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var hexInput: String = "#0071E3"
    @State private var selectedColor: Color = Color(hex: "#0071E3")
    @State private var selectedRole: ColorRole = .accent

    private let presetHexes = [
        "#0071E3", "#000000", "#FFFFFF", "#FF5E5B",
        "#635BFF", "#A259FF", "#0ACF83", "#F59E0B",
        "#86868B", "#1D1D1F", "#30D158", "#3B82F6"
    ]

    public init(store: BrandStore = .shared, brand: Brand) {
        self.store = store
        self.brand = brand
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Color to \(brand.name)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            // Preview Swatch
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selectedColor)
                    .frame(height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: selectedColor.opacity(0.35), radius: 8, x: 0, y: 3)

                VStack(spacing: 4) {
                    Text(name.isEmpty ? "Color Name" : name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(BrandColor(name: "", hex: hexInput).contrastTextColor)

                    Text(hexInput.uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(BrandColor(name: "", hex: hexInput).contrastTextColor.opacity(0.8))
                }
            }

            // Inputs
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color Name")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    TextField("e.g. Electric Blue, Dark Slate, Neon Lime", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hex Code")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        TextField("#HEX", text: $hexInput)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: hexInput) { newHex in
                                selectedColor = Color(hex: newHex)
                            }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Color Picker")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: selectedColor) { newColor in
                                hexInput = newColor.toHex()
                            }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Role")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    HStack(spacing: 8) {
                        ForEach(presetHexes, id: \.self) { hex in
                            Button(action: {
                                hexInput = hex
                                selectedColor = Color(hex: hex)
                            }) {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: hexInput.uppercased() == hex.uppercased() ? 2 : 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Color") {
                    let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !finalName.isEmpty else { return }
                    store.addColor(
                        to: brand,
                        name: finalName,
                        hex: hexInput,
                        role: selectedRole
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
    }
}
