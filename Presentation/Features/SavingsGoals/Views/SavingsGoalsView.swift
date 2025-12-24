import SwiftUI
import SwiftData

struct SavingsGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavingsGoal.createdAt, order: .reverse) private var goals: [SavingsGoal]

    @State private var showingAddGoal = false
    @State private var selectedGoal: SavingsGoal?

    var body: some View {
        NavigationStack {
            Group {
                if goals.isEmpty {
                    EmptySavingsGoalsView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(goals) { goal in
                                SavingsGoalCard(goal: goal)
                                    .onTapGesture {
                                        selectedGoal = goal
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(String(localized: "savings.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddSavingsGoalView()
            }
            .sheet(item: $selectedGoal) { goal in
                SavingsGoalDetailView(goal: goal)
            }
        }
    }
}

// MARK: - Savings Goal Card

struct SavingsGoalCard: View {
    @Bindable var goal: SavingsGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundStyle(Color(hex: goal.colorHex) ?? .accentColor)
                    .frame(width: 44, height: 44)
                    .background((Color(hex: goal.colorHex) ?? .accentColor).opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.headline)

                    if let daysRemaining = goal.daysRemaining {
                        Text(String(localized: "savings.days_remaining \(daysRemaining)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if goal.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: goal.colorHex) ?? .accentColor)
                            .frame(width: geometry.size.width * goal.progress, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(goal.formattedCurrentAmount)
                        .font(.subheadline.bold())

                    Spacer()

                    Text(goal.formattedTargetAmount)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats row
            HStack {
                VStack(alignment: .leading) {
                    Text(String(localized: "savings.progress"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(goal.progressPercentage)%")
                        .font(.subheadline.bold())
                }

                Spacer()

                VStack(alignment: .center) {
                    Text(String(localized: "savings.remaining"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(goal.formattedRemainingAmount)
                        .font(.subheadline.bold())
                }

                Spacer()

                if let dailyNeeded = goal.dailySavingsNeeded {
                    VStack(alignment: .trailing) {
                        Text(String(localized: "savings.daily_needed"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencySettings.shared.defaultCurrency.format(dailyNeeded))
                            .font(.subheadline.bold())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Empty State

struct EmptySavingsGoalsView: View {
    var body: some View {
        ContentUnavailableView {
            Label(String(localized: "savings.no_goals"), systemImage: "target")
        } description: {
            Text(String(localized: "savings.no_goals_description"))
        }
    }
}

// MARK: - Add Savings Goal View

struct AddSavingsGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var targetAmount: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var selectedIcon: String = "target"
    @State private var selectedColor: String = "#007AFF"
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "savings.goal_name"), text: $name)

                    HStack {
                        Text(CurrencySettings.shared.defaultCurrency.symbol)
                        TextField(String(localized: "savings.target_amount"), text: $targetAmount)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Toggle(String(localized: "savings.set_deadline"), isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker(
                            String(localized: "savings.deadline"),
                            selection: $deadline,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    }
                }

                Section(String(localized: "savings.appearance")) {
                    // Icon picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SavingsGoal.presetIcons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color(hex: selectedColor) ?? .accentColor : Color(.systemGray5))
                                    .clipShape(Circle())
                                    .onTapGesture {
                                        selectedIcon = icon
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Color picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(SavingsGoal.presetColors, id: \.self) { color in
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

                Section(String(localized: "savings.note_optional")) {
                    TextField(String(localized: "savings.note_placeholder"), text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(String(localized: "savings.add_goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        saveGoal()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Decimal(string: targetAmount) ?? 0 > 0
    }

    private func saveGoal() {
        guard let amount = Decimal(string: targetAmount) else { return }

        let goal = SavingsGoal(
            name: name.trimmingCharacters(in: .whitespaces),
            targetAmount: amount,
            deadline: hasDeadline ? deadline : nil,
            icon: selectedIcon,
            colorHex: selectedColor,
            note: note
        )

        modelContext.insert(goal)
        dismiss()
    }
}

// MARK: - Savings Goal Detail View

struct SavingsGoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var goal: SavingsGoal

    @State private var showingAddSavings = false
    @State private var showingWithdraw = false
    @State private var showingDeleteAlert = false
    @State private var amountToAdd: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: goal.icon)
                            .font(.system(size: 50))
                            .foregroundStyle(Color(hex: goal.colorHex) ?? .accentColor)
                            .frame(width: 100, height: 100)
                            .background((Color(hex: goal.colorHex) ?? .accentColor).opacity(0.15))
                            .clipShape(Circle())

                        Text(goal.name)
                            .font(.title2.bold())

                        if goal.isCompleted {
                            Label(String(localized: "savings.completed"), systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.top)

                    // Progress
                    VStack(spacing: 8) {
                        Text("\(goal.progressPercentage)%")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: goal.colorHex) ?? .accentColor)

                        Text("\(goal.formattedCurrentAmount) / \(goal.formattedTargetAmount)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(height: 16)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: goal.colorHex) ?? .accentColor)
                                .frame(width: geometry.size.width * goal.progress, height: 16)
                        }
                    }
                    .frame(height: 16)
                    .padding(.horizontal)

                    // Stats
                    HStack(spacing: 20) {
                        StatCard(
                            title: String(localized: "savings.remaining"),
                            value: goal.formattedRemainingAmount,
                            icon: "hourglass"
                        )

                        if let daysRemaining = goal.daysRemaining {
                            StatCard(
                                title: String(localized: "savings.days_left"),
                                value: "\(daysRemaining)",
                                icon: "calendar"
                            )
                        }

                        if let dailyNeeded = goal.dailySavingsNeeded {
                            StatCard(
                                title: String(localized: "savings.per_day"),
                                value: CurrencySettings.shared.defaultCurrency.format(dailyNeeded),
                                icon: "chart.line.uptrend.xyaxis"
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Action buttons
                    if !goal.isCompleted {
                        HStack(spacing: 16) {
                            Button {
                                showingAddSavings = true
                            } label: {
                                Label(String(localized: "savings.add_savings"), systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(hex: goal.colorHex) ?? .accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                showingWithdraw = true
                            } label: {
                                Label(String(localized: "savings.withdraw"), systemImage: "minus.circle.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray5))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Note
                    if !goal.note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "savings.note"))
                                .font(.headline)

                            Text(goal.note)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .alert(String(localized: "savings.add_savings"), isPresented: $showingAddSavings) {
                TextField(String(localized: "savings.amount"), text: $amountToAdd)
                    .keyboardType(.decimalPad)
                Button(String(localized: "common.cancel"), role: .cancel) {
                    amountToAdd = ""
                }
                Button(String(localized: "common.add")) {
                    if let amount = Decimal(string: amountToAdd) {
                        goal.addSavings(amount)
                    }
                    amountToAdd = ""
                }
            }
            .alert(String(localized: "savings.withdraw"), isPresented: $showingWithdraw) {
                TextField(String(localized: "savings.amount"), text: $amountToAdd)
                    .keyboardType(.decimalPad)
                Button(String(localized: "common.cancel"), role: .cancel) {
                    amountToAdd = ""
                }
                Button(String(localized: "savings.withdraw"), role: .destructive) {
                    if let amount = Decimal(string: amountToAdd) {
                        goal.withdrawSavings(amount)
                    }
                    amountToAdd = ""
                }
            }
            .alert(String(localized: "savings.delete_goal"), isPresented: $showingDeleteAlert) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.delete"), role: .destructive) {
                    modelContext.delete(goal)
                    dismiss()
                }
            } message: {
                Text(String(localized: "savings.delete_confirm"))
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SavingsGoalsView()
        .modelContainer(for: [SavingsGoal.self], inMemory: true)
}
