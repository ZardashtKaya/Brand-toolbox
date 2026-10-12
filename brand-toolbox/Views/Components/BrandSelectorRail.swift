import SwiftUI

@MainActor
public struct BrandSelectorRail: View {
    @ObservedObject var store: BrandStore
    public let onAddBrand: () -> Void

    public init(store: BrandStore = .shared, onAddBrand: @escaping () -> Void) {
        self.store = store
        self.onAddBrand = onAddBrand
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.brands) { brand in
                    let isSelected = store.selectedBrand?.id == brand.id
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            store.selectedBrandId = brand.id
                        }
                    }) {
                        HStack(spacing: 6) {
                            // Brand Icon / Dot
                            ZStack {
                                Circle()
                                    .fill(brand.accentColor.opacity(isSelected ? 0.9 : 0.4))
                                    .frame(width: 20, height: 20)

                                Image(systemName: brand.iconSymbol)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text(brand.name)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.16) : Color.white.opacity(0.05))
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected ? brand.accentColor.opacity(0.7) : Color.white.opacity(0.1),
                                    lineWidth: isSelected ? 1.5 : 1
                                )
                        )
                        .shadow(
                            color: isSelected ? brand.accentColor.opacity(0.3) : .clear,
                            radius: 6,
                            x: 0,
                            y: 2
                        )
                    }
                    .buttonStyle(.plain)
                    .help(brand.tagline.isEmpty ? brand.name : "\(brand.name) — \(brand.tagline)")
                    .contextMenu {
                        Button("Rename / Edit...") {
                            // Can trigger edit
                        }
                        if store.brands.count > 1 {
                            Button("Delete Brand", role: .destructive) {
                                store.deleteBrand(brand)
                            }
                        }
                    }
                }

                // Plus Add Button
                Button(action: onAddBrand) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                            )
                            .foregroundColor(Color.white.opacity(0.2))
                    )
                }
                .buttonStyle(.plain)
                .help("Create a new brand")
            }
            .padding(.vertical, 2)
        }
    }
}
