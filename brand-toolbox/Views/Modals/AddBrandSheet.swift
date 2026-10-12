import SwiftUI

public struct AddBrandSheet: View {
    @ObservedObject var store: BrandStore
    public var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var tagline: String = ""
    @State private var selectedSymbol: String = "sparkles"
    @State private var accentColor: Color = Color(hex: "#0071E3")
    @State private var accentHex: String = "#0071E3"

    private let symbols = [
        "sparkles", "paintpalette.fill", "bolt.fill", "flame.fill",
        "apple.logo", "capsule.fill", "triangle.fill", "creditcard.fill",
        "star.fill", "crown.fill", "globe", "leaf.fill",
        "cube.transparent", "heart.fill", "atom", "wand.and.stars"
    ]

    private let presetHexes = [
        "#0071E3", "#FF5E5B", "#635BFF", "#A259FF",
        "#0ACF83", "#F59E0B", "#EC4899", "#14B8A6",
        "#3B82F6", "#8B5CF6", "#EF4444", "#10B981"
    ]

    public init(store: BrandStore = .shared, onClose: (() -> Void)? = nil) {
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create New Brand")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.15))
                    Text("Add a custom brand with colors and logos")
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

            // Preview Card
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accentColor)
                        .frame(width: 44, height: 44)
                        .shadow(color: accentColor.opacity(0.35), radius: 6, x: 0, y: 3)

                    Image(systemName: selectedSymbol)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name.isEmpty ? "Brand Name" : name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.15))
                    Text(tagline.isEmpty ? "Tagline or description" : tagline)
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.96)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.88), lineWidth: 1))

            // Inputs
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Brand Name")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))
                    TextField("e.g. Acme Studio, Personal Brand", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Tagline (Optional)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))
                    TextField("e.g. Design System & Mobile App", text: $tagline)
                        .textFieldStyle(.roundedBorder)
                }

                // Symbol Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Brand Symbol")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                        ForEach(symbols, id: \.self) { sym in
                            let isPicked = selectedSymbol == sym
                            Button(action: { selectedSymbol = sym }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isPicked ? accentColor.opacity(0.15) : Color(white: 0.95))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(isPicked ? accentColor : Color.clear, lineWidth: 1.5)
                                        )
                                        .frame(height: 32)

                                    Image(systemName: sym)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(isPicked ? accentColor : Color(red: 0.3, green: 0.3, blue: 0.35))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Accent Color
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Accent Color")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))
                        Spacer()
                        ColorPicker("", selection: $accentColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: accentColor) { newColor in
                                accentHex = newColor.toHex()
                            }
                    }

                    HStack(spacing: 6) {
                        ForEach(presetHexes, id: \.self) { hex in
                            let isCur = accentHex.uppercased() == hex.uppercased()
                            Button(action: {
                                accentHex = hex
                                accentColor = Color(hex: hex)
                            }) {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(isCur ? Color.black : Color.black.opacity(0.15), lineWidth: isCur ? 2.2 : 0.8)
                                    )
                                    .shadow(color: Color(hex: hex).opacity(0.3), radius: isCur ? 3 : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onClose?()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Brand") {
                    let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !finalName.isEmpty else { return }
                    store.addBrand(
                        name: finalName,
                        tagline: tagline.trimmingCharacters(in: .whitespacesAndNewlines),
                        iconSymbol: selectedSymbol,
                        accentHex: accentHex
                    )
                    onClose?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(width: 380)
        .background(Color.white)
    }
}
