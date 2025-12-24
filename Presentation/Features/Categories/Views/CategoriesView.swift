import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var selectedType: TransactionType = .expense
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?

    private var filteredCategories: [Category] {
        categories.filter { $0.type == selectedType }
    }

    var body: some View {
        List {
            Picker(String(localized: "transactions.type.expense"), selection: $selectedType) {
                Text(String(localized: "transactions.type.expense")).tag(TransactionType.expense)
                Text(String(localized: "transactions.type.income")).tag(TransactionType.income)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            ForEach(filteredCategories, id: \.id) { category in
                CategoryRow(category: category)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !category.isDefault {
                            editingCategory = category
                        }
                    }
            }
            .onDelete(perform: deleteCategories)
            .onMove(perform: moveCategories)
        }
        .navigationTitle(String(localized: "categories.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            CategoryEditView(type: selectedType)
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditView(category: category)
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            let category = filteredCategories[index]
            if !category.isDefault {
                modelContext.delete(category)
            }
        }
        try? modelContext.save()
        AppDataPreloader.shared.refreshCategories(using: modelContext)
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var items = filteredCategories
        items.move(fromOffsets: source, toOffset: destination)

        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }

        try? modelContext.save()
        AppDataPreloader.shared.refreshCategories(using: modelContext)
    }
}

// MARK: - Category Row
struct CategoryRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(category.color)
                .frame(width: 36, height: 36)
                .background(category.color.opacity(0.15))
                .clipShape(Circle())

            Text(category.name)
                .font(.body)

            Spacer()

            if category.isDefault {
                Text(String(localized: "categories.default"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Category Edit View
struct CategoryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let category: Category?
    let type: TransactionType

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String

    private let icons = [
        "fork.knife", "bag.fill", "car.fill", "house.fill",
        "phone.fill", "cross.case.fill", "book.fill", "gamecontroller.fill",
        "tram.fill", "airplane", "gift.fill", "heart.fill",
        "banknote.fill", "creditcard.fill", "cart.fill", "cup.and.saucer.fill"
    ]

    private let colors = [
        "#FF9500", "#FF2D55", "#34C759", "#AF52DE",
        "#5856D6", "#FF3B30", "#007AFF", "#FFCC00",
        "#00C7BE", "#32ADE6", "#FF6482", "#8E8E93"
    ]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isEditing: Bool {
        category != nil
    }

    init(category: Category? = nil, type: TransactionType = .expense) {
        self.category = category
        self.type = category?.type ?? type
        self._name = State(initialValue: category?.name ?? "")
        self._selectedIcon = State(initialValue: category?.icon ?? "ellipsis.circle.fill")
        self._selectedColor = State(initialValue: category?.colorHex ?? "#8E8E93")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "categories.name")) {
                    TextField(String(localized: "categories.name"), text: $name)
                }

                Section(String(localized: "categories.icon")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.accentColor : Color(.tertiarySystemFill))
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(String(localized: "categories.color")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(colors, id: \.self) { colorHex in
                            Button {
                                selectedColor = colorHex
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .gray)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if selectedColor == colorHex {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .font(.headline)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Preview
                Section(String(localized: "categories.preview")) {
                    HStack(spacing: 12) {
                        Image(systemName: selectedIcon)
                            .font(.title2)
                            .foregroundStyle(Color(hex: selectedColor) ?? .gray)
                            .frame(width: 40, height: 40)
                            .background((Color(hex: selectedColor) ?? .gray).opacity(0.15))
                            .clipShape(Circle())

                        Text(name.isEmpty ? String(localized: "categories.title") : name)
                            .font(.body)
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "categories.edit") : String(localized: "categories.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        if let category = category {
            category.name = name
            category.icon = selectedIcon
            category.colorHex = selectedColor
        } else {
            let repository = CategoryRepository(modelContext: modelContext)
            _ = try? repository.create(
                name: name,
                icon: selectedIcon,
                colorHex: selectedColor,
                type: type
            )
        }

        try? modelContext.save()
        AppDataPreloader.shared.refreshCategories(using: modelContext)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
    .modelContainer(for: [Transaction.self, Category.self, Budget.self], inMemory: true)
}
