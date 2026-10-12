import SwiftUI
import AppKit

public struct AddFontSheet: View {
    @ObservedObject var store: BrandStore
    public let brand: Brand
    public var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedRole: String = "Primary"

    private let roles = ["Primary", "Headings", "Body", "Code", "Accent", "Serif"]
    private let suggestedFonts = [
        "SF Pro", "Inter", "Geist", "Söhne",
        "Helvetica Now", "Plus Jakarta Sans", "Roboto",
        "JetBrains Mono", "SF Mono", "Fira Code",
        "New York", "Playfair Display", "Whyte Inktrap"
    ]

    public init(store: BrandStore = .shared, brand: Brand, onClose: (() -> Void)? = nil) {
        self.store = store
        self.brand = brand
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Font • \(brand.name)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.15))
                    Text("Store font names as reference for this brand")
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
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.96))
                    .frame(height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(white: 0.88), lineWidth: 1)
                    )

                VStack(spacing: 4) {
                    Text(name.isEmpty ? "The quick brown fox jumps" : name)
                        .font(name.isEmpty ? .system(size: 16, weight: .semibold) : (NSFont(name: name, size: 17) != nil ? .custom(name, size: 17) : .system(size: 17, weight: .semibold)))
                        .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.15))
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(brand.accentColor)
                            .frame(width: 6, height: 6)
                        Text(selectedRole.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(brand.accentColor)
                            .tracking(0.6)
                    }
                }
                .padding(.horizontal, 14)
            }
            .frame(maxWidth: .infinity)

            // Form Inputs
            VStack(alignment: .leading, spacing: 14) {
                // Font Name
                VStack(alignment: .leading, spacing: 5) {
                    Text("Font Family / Name")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))
                    TextField("e.g. SF Pro, Inter, Söhne, Geist", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Quick Suggestions Chips
                VStack(alignment: .leading, spacing: 5) {
                    Text("Popular Suggestions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(suggestedFonts, id: \.self) { fontName in
                                let isPicked = name == fontName
                                Button(action: {
                                    name = fontName
                                }) {
                                    Text(fontName)
                                        .font(.system(size: 11, weight: isPicked ? .bold : .medium))
                                        .foregroundColor(isPicked ? .white : Color(red: 0.2, green: 0.2, blue: 0.25))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(isPicked ? brand.accentColor : Color(white: 0.94))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(isPicked ? brand.accentColor : Color(white: 0.85), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Role / Usage Grid
                VStack(alignment: .leading, spacing: 6) {
                    Text("Role / Usage")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.38))

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(roles, id: \.self) { role in
                            let isPicked = selectedRole == role
                            Button(action: {
                                selectedRole = role
                            }) {
                                Text(role)
                                    .font(.system(size: 11, weight: isPicked ? .bold : .medium))
                                    .foregroundColor(isPicked ? .white : Color(red: 0.25, green: 0.25, blue: 0.3))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(isPicked ? brand.accentColor : Color(white: 0.94))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .stroke(isPicked ? brand.accentColor : Color(white: 0.85), lineWidth: 1)
                                    )
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

                Button("Add Font") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.addFont(to: brand, name: trimmed, role: selectedRole)
                    onClose?()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(brand.accentColor)
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

// MARK: - Previews

#Preview("Add Font Sheet") {
    AddFontSheet(store: .shared, brand: .mock)
}
