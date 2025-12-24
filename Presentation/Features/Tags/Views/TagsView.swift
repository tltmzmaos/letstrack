import SwiftUI
import SwiftData

struct TagsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.usageCount, order: .reverse) private var tags: [Tag]

    @State private var showingAddTag = false
    @State private var selectedTag: Tag?

    var body: some View {
        NavigationStack {
            Group {
                if tags.isEmpty {
                    EmptyTagsView()
                } else {
                    List {
                        ForEach(tags) { tag in
                            TagRow(tag: tag)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedTag = tag
                                }
                        }
                        .onDelete(perform: deleteTags)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(String(localized: "tags.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTag = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddTag) {
                AddTagView()
            }
            .sheet(item: $selectedTag) { tag in
                EditTagView(tag: tag)
            }
        }
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tags[index])
        }
        try? modelContext.save()
        AppDataPreloader.shared.refreshTags(using: modelContext)
    }
}

// MARK: - Tag Row

struct TagRow: View {
    @Bindable var tag: Tag

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: tag.colorHex) ?? .accentColor)
                .frame(width: 12, height: 12)

            Text(tag.name)
                .font(.body)

            Spacer()

            Text("\(tag.usageCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

struct EmptyTagsView: View {
    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "tags.no_tags"), systemImage: "tag")
        } description: {
            Text(String(localized: "tags.no_tags_description"))
        }
    }
}

// MARK: - Add Tag View

struct AddTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedColor: String = "#007AFF"

    private let presetColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#5856D6", "#FF2D55", "#AF52DE", "#00C7BE",
        "#FFD60A", "#8E8E93"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "tags.name"), text: $name)
                }

                Section(String(localized: "tags.color")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(presetColors, id: \.self) { color in
                                Circle()
                                    .fill(Color(hex: color) ?? .gray)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    HStack {
                        Text(String(localized: "tags.preview"))
                            .foregroundStyle(.secondary)

                        Spacer()

                        TagPreview(name: name.isEmpty ? String(localized: "tags.sample") : name, colorHex: selectedColor)
                    }
                }
            }
            .navigationTitle(String(localized: "tags.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        saveTag()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func saveTag() {
        let tag = Tag(
            name: name.trimmingCharacters(in: .whitespaces),
            colorHex: selectedColor
        )
        modelContext.insert(tag)
        try? modelContext.save()
        AppDataPreloader.shared.refreshTags(using: modelContext)
        dismiss()
    }
}

// MARK: - Edit Tag View

struct EditTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var tag: Tag

    @State private var showingDeleteAlert = false

    private let presetColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#5856D6", "#FF2D55", "#AF52DE", "#00C7BE",
        "#FFD60A", "#8E8E93"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "tags.name"), text: $tag.name)
                }

                Section(String(localized: "tags.color")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(presetColors, id: \.self) { color in
                                Circle()
                                    .fill(Color(hex: color) ?? .gray)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if tag.colorHex == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .onTapGesture {
                                        tag.colorHex = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    HStack {
                        Text(String(localized: "tags.usage_count"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(tag.usageCount)")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label(String(localized: "tags.delete"), systemImage: "trash")
                    }
                }
            }
            .navigationTitle(String(localized: "tags.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        try? modelContext.save()
                        AppDataPreloader.shared.refreshTags(using: modelContext)
                        dismiss()
                    }
                }
            }
            .alert(String(localized: "tags.delete"), isPresented: $showingDeleteAlert) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.delete"), role: .destructive) {
                    modelContext.delete(tag)
                    try? modelContext.save()
                    AppDataPreloader.shared.refreshTags(using: modelContext)
                    dismiss()
                }
            } message: {
                Text(String(localized: "tags.delete_confirm"))
            }
        }
    }
}

// MARK: - Tag Preview

struct TagPreview: View {
    let name: String
    let colorHex: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: colorHex) ?? .accentColor)
                .frame(width: 8, height: 8)

            Text(name)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((Color(hex: colorHex) ?? .accentColor).opacity(0.15))
        .clipShape(Capsule())
    }
}

#Preview {
    TagsView()
        .modelContainer(for: [Tag.self], inMemory: true)
}
