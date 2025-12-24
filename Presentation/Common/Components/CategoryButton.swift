import SwiftUI

/// Reusable category selection button
struct CategoryButton: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        Button {
            haptic.impactOccurred()
            action()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(isSelected ? category.color : category.color.opacity(0.15))
                        .foregroundStyle(isSelected ? .white : category.color)
                        .clipShape(Circle())

                    if isSelected {
                        Circle()
                            .stroke(category.color, lineWidth: 2)
                            .frame(width: 52, height: 52)
                    }
                }

                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? category.color : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.name)")
        .accessibilityHint(isSelected ? String(localized: "accessibility.selected") : String(localized: "accessibility.tap_to_select"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Category selection grid
struct CategorySelectionGrid: View {
    let categories: [Category]
    let transactionType: TransactionType
    @Binding var selectedCategory: Category?

    var filteredCategories: [Category] {
        categories.filter { $0.type == transactionType }
    }

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 70), spacing: 12)
        ], spacing: 12) {
            ForEach(filteredCategories, id: \.id) { category in
                CategoryButton(
                    category: category,
                    isSelected: selectedCategory?.id == category.id
                ) {
                    selectedCategory = category
                }
            }
        }
        .padding(.vertical, 8)
    }
}
